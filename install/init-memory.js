#!/usr/bin/env node
// تهيئة نظام الذاكرة: إنشاء deepseek.db من schema.sql + مجلد الذاكرة + MEMORY.md
// الاستخدام:
//   node init-memory.js --claude-dir <path>

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

const args = parseArgs(process.argv);
const claudeDir = args["claude-dir"] || p.join(os.homedir(), ".claude");
const repoDir = p.join(__dirname, "..");

// ١. قاعدة SQLite من المخطط
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

// ٢. مجلد الذاكرة (معرّف المشروع مشتق من مسار المنزل)
const projectId = os.homedir().replace(/[\\/:]/g, "-");
const memDir = p.join(claudeDir, "projects", projectId, "memory");
fs.mkdirSync(memDir, { recursive: true });
console.log("✓ مجلد الذاكرة: " + memDir);

// ٣. MEMORY.md فارغ إن لم يوجد
const indexFile = p.join(memDir, "MEMORY.md");
if (!fs.existsSync(indexFile)) {
  const tpl = fs.readFileSync(
    p.join(repoDir, "templates", "memory", "MEMORY.md"),
    "utf8",
  );
  fs.writeFileSync(indexFile, tpl, "utf8");
  console.log("✓ أُنشئ فهرس MEMORY.md");
} else {
  console.log("⚠ MEMORY.md موجود — لا نلمسه");
}
