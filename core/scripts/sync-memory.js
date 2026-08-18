// مزامنة الذاكرة — ثنائية الاتجاه: hallucinations/tool_usage (SQLite → Markdown، المصدر SQLite)، memories (Markdown → SQLite، المصدر Markdown)
const fs = require("fs"),
  p = require("path"),
  h = require("os").homedir();
const dbPath = p.join(h, ".claude", "data", "deepseek.db");
// معرّف مشروع الذاكرة يُشتق من مسار المنزل على نمط Claude Code (C:\Users\name → C--Users-name)
// بدل تثبيت اسم مستخدم — يجعل السكربت محمولاً لأي جهاز
const projectId = h.replace(/[\\/:]/g, "-");
const memDir = p.join(h, ".claude", "projects", projectId, "memory");
const { DatabaseSync } = require("node:sqlite");
const db = new DatabaseSync(dbPath);

console.log("🔄 مزامنة SQLite → Markdown...\n");

// 1. Sync hallucinations → deepseek-hallucinations.md
// يعيد بناء الملف كليًا من SQLite (لا تكرار، لا تراكم عبر التشغيلات)
try {
  const hal = db
    .prepare("SELECT * FROM hallucinations ORDER BY created_at DESC")
    .all();
  const halFile = p.join(memDir, "deepseek-hallucinations.md");

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
    if (hh.correct_value) lines += `\n- **المسار الصحيح**: ${hh.correct_value}`;
    if (hh.context) lines += `\n- **السياق**: ${hh.context}`;
    if (hh.lesson) lines += `\n- **الدرس**: ${hh.lesson}`;
    return lines;
  };

  const types = ["path", "function", "library", "other"];

  let content = `---
name: deepseek-hallucinations
description: سجل الهلوسات (hallucinations) — أنماط الافتراءات المتكررة لتجنبها مستقبلاً
metadata:
  node_type: memory
  type: feedback
  severity: critical
  domain: ai-quality
---

# 🚨 سجل هلوسات DeepSeek

## لماذا هذا الملف؟

لتوثيق الحالات التي يختلق فيها DeepSeek معلومات غير صحيحة (مسارات وهمية، دوال غير موجودة، مكتبات مختلقة). الرجوع لهذا الملف قبل كل إجابة يقلل تكرار الأخطاء.
`;

  for (const t of types) {
    const title = sectionFor(t);
    const entries = hal.filter((hh) => hh.pattern_type === t);
    content += `\n## نمط الهلوسة: ${title}\n\n`;
    if (entries.length === 0) {
      content += `### حادثة #1\n- **التاريخ**: (يُملأ عند الحدوث)\n- **${fieldFor(t)}**: (placeholder)\n- **السياق**: (ماذا كان السؤال؟)\n- **الدرس**: (كيف نتجنب هذا مستقبلاً؟)\n\n`;
    } else {
      entries.forEach((hh, i) => {
        content += mkEntry(hh, i + 1) + "\n\n";
      });
    }
  }

  content += `## إحصائيات\n\n- **إجمالي الحوادث**: ${hal.length}\n- **آخر تحديث**: ${new Date().toISOString().split("T")[0]}\n- **أكثر نمط متكرر**: ${Object.entries(byType).sort((a, b) => b[1] - a[1])[0]?.[0] || "يُحدد لاحقاً"}\n\n## روابط\n\n- [[deepseek-quality-tracker]]\n- [[deepseek-commands]]\n\n---\n\n> **قاعدة ذهبية**: إذا لم تكن متأكداً من وجود ملف/دالة/مكتبة، استخدم أدوات البحث (Grep/Glob) قبل الافتراض.\n`;

  fs.writeFileSync(halFile, content, "utf8");
  console.log("✅ deepseek-hallucinations.md: " + hal.length + " حدث");
} catch (e) {
  console.log("⚠️ Hallucinations sync: " + e.message);
}

// 2. Sync tool_usage patterns → deepseek-quality-tracker.md
try {
  const tools = db
    .prepare(
      "SELECT tool_name,COUNT(*)c,SUM(CASE WHEN success=1 THEN 1 ELSE 0 END)ok FROM tool_usage GROUP BY tool_name ORDER BY c DESC",
    )
    .all();
  const qFile = p.join(memDir, "deepseek-quality-tracker.md");
  let qc = fs.readFileSync(qFile, "utf8");

  if (tools.length > 0) {
    const topTools = tools
      .slice(0, 5)
      .map(
        (t) =>
          `- ${t.tool_name}: ${t.c} استخدام (نجاح ${Math.round((t.ok / t.c) * 100)}%)`,
      )
      .join("\n");
    const worstTool =
      tools
        .filter((t) => t.ok / t.c < 0.5)
        .map((t) => t.tool_name)
        .join(", ") || "لا يوجد";

    // نمط جشع يبتلع كل الأسطر المتتالية التي تبدأ بـ "- " — النمط غير الجشع القديم
    // كان يطابق سطراً واحداً فقط ويستبدله بخمسة فيتبقّى القديم ويتضخم الملف كل تشغيل
    qc = qc.replace(
      /(أنماط الضعف[^\n]*\n)(?:-[^\n]*\n)*/,
      "أنماط الضعف ⚠️\n- معدل فشل مرتفع: " + worstTool + "\n",
    );
    qc = qc.replace(
      /(أخطاء متكررة[^\n]*\n)(?:-[^\n]*\n)*/,
      "أخطاء متكررة 🐛\n" + topTools + "\n",
    );

    fs.writeFileSync(qFile, qc, "utf8");
    console.log("✅ deepseek-quality-tracker.md: " + tools.length + " أدوات");
  }
} catch (e) {
  console.log("⚠️ Quality tracker sync: " + e.message);
}

// 3. Ensure all memory .md files are in SQLite memories table
try {
  const files = fs
    .readdirSync(memDir, { recursive: true })
    .filter((f) => f.endsWith(".md"));
  for (const f of files) {
    const name = f.replace(/\\/g, "/").replace(".md", "");
    const full = p.join(memDir, f);
    if (fs.statSync(full).isFile() && name !== "MEMORY") {
      const content = fs.readFileSync(full, "utf8");
      const descMatch = content.match(/description:\s*(.+)/);
      const typeMatch = content.match(/^\s*type:\s*(.+)/m);
      const desc = descMatch ? descMatch[1] : "";
      const allowedTypes = [
        "user",
        "feedback",
        "project",
        "reference",
        "pattern",
        "tool",
        "session",
      ];
      const type =
        typeMatch && allowedTypes.includes(typeMatch[1].trim())
          ? typeMatch[1].trim()
          : "reference";

      db.prepare(
        "INSERT OR IGNORE INTO memories(name,description,type,content) VALUES(?,?,?,?)",
      ).run(name, desc, type, content);
      db.prepare(
        "UPDATE memories SET updated_at=datetime('now'),content=? WHERE name=?",
      ).run(content, name);
    }
  }
  // حذف سجلات الملفات التي لم تعد موجودة (المؤرشفة/المحذوفة) — يمنع تراكم السجلات الميتة
  const validNames = new Set();
  for (const f of files) {
    const n = f.replace(/\\/g, "/").replace(".md", "");
    const full = p.join(memDir, f);
    if (fs.statSync(full).isFile() && n !== "MEMORY") validNames.add(n);
  }
  const allNames = db.prepare("SELECT name FROM memories").all();
  let removed = 0;
  for (const r of allNames) {
    if (!validNames.has(r.name)) {
      db.prepare("DELETE FROM memories WHERE name=?").run(r.name);
      removed++;
    }
  }
  if (removed > 0)
    console.log("🧹 حُذفت " + removed + " سجلات قديمة (ملفاتها غابت)");

  const cnt = db.prepare("SELECT COUNT(*)as c FROM memories").get();
  console.log("✅ ذكريات SQLite: " + cnt.c + " ملف");
} catch (e) {
  console.log("⚠️ Memories sync: " + e.message);
}

db.close();
console.log("\n✅ المزامنة اكتملت");
