#!/usr/bin/env node
// تهيئة نظام الذاكرة بطبقتين:
//   • عامة  → ~/.claude/memory/            تُحمّل كل جلسة (تفضيلات، أنماط فشل، هلوسات)
//   • مشروع → ~/.claude/projects/<id>/memory/  تُحمّل في مسار ذلك المشروع فقط
//
// الاستخدام:
//   node init-memory.js --claude-dir <path> [--project-dir <path>]

const fs = require("fs");
const os = require("os");
const p = require("path");
const { DatabaseSync } = require("node:sqlite");

function parseArgs(argv) {
  const a = {};
  for (let i = 2; i < argv.length; i++) {
    const k = argv[i];
    if (k.startsWith("--")) {
      const name = k.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith("--")) {
        a[name] = next;
        i++;
      } else a[name] = true;
    }
  }
  return a;
}

// معرّف المشروع على نمط Claude Code: مسار العمل مع استبدال الفواصل بشرطات
function projectIdFrom(dir) {
  return p.resolve(dir).replace(/[\\/:]/g, "-");
}

const args = parseArgs(process.argv);
const claudeDir = args["claude-dir"] || p.join(os.homedir(), ".claude");
// مجلد المشروع = مسار العمل الحالي افتراضاً (لا مجلد المنزل)
const projectDir = args["project-dir"] || process.cwd();
const repoDir = p.join(__dirname, "..");

// ── ١. قاعدة SQLite من المخطط ──
const dataDir = p.join(claudeDir, "data");
fs.mkdirSync(dataDir, { recursive: true });
const dbPath = p.join(dataDir, "deepseek.db");

if (fs.existsSync(dbPath)) {
  console.log("⚠ قاعدة ذاكرة موجودة — لا نلمسها: " + dbPath);
} else {
  const schema = fs.readFileSync(
    p.join(repoDir, "templates", "memory", "schema.sql"),
    "utf8",
  );
  const db = new DatabaseSync(dbPath);
  db.exec(schema);
  db.close();
  console.log("✓ أُنشئت قاعدة الذاكرة: " + dbPath);
}

// ── ٢. الطبقة العامة ──
const globalDir = p.join(claudeDir, "memory");
fs.mkdirSync(globalDir, { recursive: true });
const globalIndex = p.join(globalDir, "MEMORY.md");
if (!fs.existsSync(globalIndex)) {
  fs.writeFileSync(
    globalIndex,
    fs.readFileSync(
      p.join(repoDir, "templates", "memory", "MEMORY.md"),
      "utf8",
    ),
    "utf8",
  );
  console.log("✓ الطبقة العامة: " + globalDir);
} else {
  console.log("⚠ فهرس الطبقة العامة موجود — لا نلمسه");
}

// ── ٣. طبقة المشروع الحالي ──
const projectId = projectIdFrom(projectDir);
const projMemDir = p.join(claudeDir, "projects", projectId, "memory");
fs.mkdirSync(projMemDir, { recursive: true });
const projIndex = p.join(projMemDir, "MEMORY.md");
if (!fs.existsSync(projIndex)) {
  fs.writeFileSync(
    projIndex,
    `# ذاكرة المشروع\n\n> المسار: \`${projectDir}\`\n> المعرّف: \`${projectId}\`\n\nتُحمّل هذه الذاكرة عند العمل في هذا المسار فقط.\nالتفضيلات وأنماط الفشل العامة مكانها \`~/.claude/memory/\`.\n\n## الجلسات\n\n_(تُضاف عبر \`/mem-save\`)_\n\n## حقائق المشروع\n\n_(قرارات معمارية، قيود، تفاصيل لا تُستنتج من الكود)_\n`,
    "utf8",
  );
  console.log("✓ طبقة المشروع: " + projMemDir);
} else {
  console.log("⚠ فهرس المشروع موجود — لا نلمسه");
}

console.log("");
console.log("الطبقتان جاهزتان:");
console.log("  عامة  → " + globalDir);
console.log("  مشروع → " + projMemDir);
