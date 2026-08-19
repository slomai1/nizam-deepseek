// مزامنة الذاكرة بطبقتين
//   • عامة  → ~/.claude/memory/               تُخزَّن بـ project = NULL
//   • مشروع → ~/.claude/projects/<id>/memory/  تُخزَّن بمعرّف المشروع
//
// الاتجاهات: hallucinations/tool_usage (SQLite → Markdown، المصدر SQLite)
//            memories (Markdown → SQLite، المصدر Markdown)
const fs = require("fs"),
  p = require("path"),
  os = require("os"),
  h = os.homedir();

const dbPath = p.join(h, ".claude", "data", "deepseek.db");
const globalDir = p.join(h, ".claude", "memory");

// معرّف المشروع من مسار العمل الحالي (نمط Claude Code) — لا من مجلد المنزل
const projectId = p.resolve(process.cwd()).replace(/[\\/:]/g, "-");
const projectDir = p.join(h, ".claude", "projects", projectId, "memory");

const { DatabaseSync } = require("node:sqlite");
const db = new DatabaseSync(dbPath);

console.log("🔄 مزامنة SQLite → Markdown...\n");

// ── 1. Hallucinations → ملف في الطبقة العامة (أنماط الفشل تعبر المشاريع) ──
try {
  const hal = db
    .prepare("SELECT * FROM hallucinations ORDER BY created_at DESC")
    .all();
  fs.mkdirSync(globalDir, { recursive: true });
  const halFile = p.join(globalDir, "deepseek-hallucinations.md");

  const byType = {};
  hal.forEach((hh) => {
    byType[hh.pattern_type] = (byType[hh.pattern_type] || 0) + 1;
  });

  const fieldFor = (t) =>
    t === "path"
      ? "المسار المُختلَق"
      : t === "function"
        ? "الدالة المُختلَقة"
        : t === "library"
          ? "المكتبة المختلقة"
          : "الخاصية المختلقة";
  const sectionFor = (t) =>
    t === "path"
      ? "مسارات الملفات"
      : t === "function"
        ? "دوال غير موجودة"
        : t === "library"
          ? "مكتبات وهمية"
          : "إعدادات/خصائص مختلقة";

  const mkEntry = (hh, n) => {
    let lines = `### حادثة #${n}\n- **التاريخ**: ${(hh.created_at || "").split("T")[0] || "غير معروف"}\n- **${fieldFor(hh.pattern_type)}**: ${hh.hallucinated_value || ""}`;
    if (hh.correct_value)
      lines += `\n- **القيمة الصحيحة**: ${hh.correct_value}`;
    if (hh.context) lines += `\n- **السياق**: ${hh.context}`;
    if (hh.lesson) lines += `\n- **الدرس**: ${hh.lesson}`;
    return lines;
  };

  const types = ["path", "function", "library", "other"];

  let content = `---
name: deepseek-hallucinations
description: سجل الهلوسات — أنماط الافتراءات المتكررة لتجنبها مستقبلاً
metadata:
  node_type: memory
  type: feedback
  severity: critical
  layer: global
---

# 🚨 سجل الهلوسات

> طبقة عامة: هذا السجل يعبر كل المشاريع لأن أنماط الفشل لا تخص مشروعاً بعينه.
`;

  for (const t of types) {
    const entries = hal.filter((hh) => hh.pattern_type === t);
    content += `\n## نمط الهلوسة: ${sectionFor(t)}\n\n`;
    if (entries.length === 0) {
      content += `_(لا حوادث مسجلة بعد)_\n\n`;
    } else {
      entries.forEach((hh, i) => {
        content += mkEntry(hh, i + 1) + "\n\n";
      });
    }
  }

  content += `## إحصائيات\n\n- **إجمالي الحوادث**: ${hal.length}\n- **آخر تحديث**: ${new Date().toISOString().split("T")[0]}\n- **أكثر نمط تكراراً**: ${Object.entries(byType).sort((a, b) => b[1] - a[1])[0]?.[0] || "لا يوجد"}\n\n---\n\n> **قاعدة ذهبية**: إذا لم تكن متأكداً من وجود ملف/دالة/مكتبة، تحقق بـ Grep/Glob قبل الافتراض.\n`;

  fs.writeFileSync(halFile, content, "utf8");
  console.log("✅ deepseek-hallucinations.md (عامة): " + hal.length + " حادثة");
} catch (e) {
  console.log("⚠️ Hallucinations sync: " + e.message);
}

// ── 2. Markdown → SQLite لكل طبقة ──
function syncLayer(dir, projectValue, label) {
  if (!fs.existsSync(dir)) {
    console.log("⏭️  " + label + ": المجلد غير موجود — تخطٍّ");
    return new Set();
  }
  const files = fs
    .readdirSync(dir, { recursive: true })
    .filter((f) => String(f).endsWith(".md"));
  const names = new Set();
  const allowedTypes = [
    "user",
    "feedback",
    "project",
    "reference",
    "pattern",
    "tool",
    "session",
  ];

  for (const f of files) {
    const name = String(f).replace(/\\/g, "/").replace(".md", "");
    const full = p.join(dir, String(f));
    if (!fs.statSync(full).isFile() || name === "MEMORY") continue;

    const content = fs.readFileSync(full, "utf8");
    const descMatch = content.match(/description:\s*(.+)/);
    const typeMatch = content.match(/^\s*type:\s*(.+)/m);
    const desc = descMatch ? descMatch[1] : "";
    const type =
      typeMatch && allowedTypes.includes(typeMatch[1].trim())
        ? typeMatch[1].trim()
        : "reference";

    // التحديث مقيَّد بنطاق الطبقة. بدون هذا القيد تستولي مزامنة مشروع على
    // سجل مشروع آخر يحمل نفس الاسم فتستبدل محتواه — تلاعب عابر للمشاريع.
    const scoped =
      projectValue === null
        ? db
            .prepare("SELECT id FROM memories WHERE name=? AND project IS NULL")
            .get(name)
        : db
            .prepare("SELECT id FROM memories WHERE name=? AND project=?")
            .get(name, projectValue);

    if (scoped) {
      db.prepare(
        "UPDATE memories SET updated_at=datetime('now'),content=?,description=?,type=? WHERE id=?",
      ).run(content, desc, type, scoped.id);
    } else {
      db.prepare(
        "INSERT INTO memories(name,description,type,content,project) VALUES(?,?,?,?,?)",
      ).run(name, desc, type, content, projectValue);
    }
    names.add(name);
  }
  console.log("✅ " + label + ": " + names.size + " ملف");
  return names;
}

try {
  const globalNames = syncLayer(globalDir, null, "الطبقة العامة");
  const projNames = syncLayer(
    projectDir,
    projectId,
    "طبقة المشروع (" + projectId + ")",
  );

  // حذف السجلات التي غابت ملفاتها — لكل طبقة على حدة
  let removed = 0;
  const cleanup = (projectValue, keep) => {
    const rows =
      projectValue === null
        ? db.prepare("SELECT name FROM memories WHERE project IS NULL").all()
        : db
            .prepare("SELECT name FROM memories WHERE project = ?")
            .all(projectValue);
    for (const r of rows) {
      if (!keep.has(r.name)) {
        if (projectValue === null)
          db.prepare(
            "DELETE FROM memories WHERE name=? AND project IS NULL",
          ).run(r.name);
        else
          db.prepare("DELETE FROM memories WHERE name=? AND project=?").run(
            r.name,
            projectValue,
          );
        removed++;
      }
    }
  };
  cleanup(null, globalNames);
  if (fs.existsSync(projectDir)) cleanup(projectId, projNames);
  if (removed > 0)
    console.log("🧹 حُذفت " + removed + " سجلات قديمة (ملفاتها غابت)");

  // صفوف يتيمة: نطاقها ليس الطبقة العامة ولا أي مشروع له مجلد ذاكرة على القرص.
  // مصدرها مخطط قديم أو مجلد مشروع حُذف. لا تُحذف تلقائياً — الحذف الصامت
  // لذاكرة قد تكون حيّة أسوأ من إبقائها؛ نبلّغ ونترك القرار للمستخدم.
  const projectsRoot = p.join(h, ".claude", "projects");
  const known = new Set();
  if (fs.existsSync(projectsRoot)) {
    for (const d of fs.readdirSync(projectsRoot)) {
      if (fs.existsSync(p.join(projectsRoot, d, "memory"))) known.add(d);
    }
  }
  const orphans = db
    .prepare(
      "SELECT project, COUNT(*) c FROM memories WHERE project IS NOT NULL GROUP BY project",
    )
    .all()
    .filter((r) => !known.has(r.project));
  if (orphans.length) {
    console.log("");
    console.log("⚠️  صفوف بنطاق لا مجلد ذاكرة له:");
    orphans.forEach((o) => console.log("   " + o.project + ": " + o.c + " صف"));
    console.log(
      "   للحذف: node ~/.claude/scripts/sync-memory.js --prune-orphans",
    );
    if (process.argv.includes("--prune-orphans")) {
      let pruned = 0;
      for (const o of orphans) {
        pruned += db
          .prepare("DELETE FROM memories WHERE project=?")
          .run(o.project).changes;
      }
      console.log("   🧹 حُذف " + pruned + " صفاً يتيماً");
    }
  }

  const total = db.prepare("SELECT COUNT(*) as c FROM memories").get();
  console.log("📊 إجمالي الذكريات في القاعدة: " + total.c);
} catch (e) {
  console.log("⚠️ Memories sync: " + e.message);
}

db.close();
console.log("\n✅ المزامنة اكتملت");
