#!/usr/bin/env node
// ترحيل قاعدة ذاكرة قائمة إلى التفرّد المركّب (name, project)
//
// السبب: `name TEXT UNIQUE` يفرض مساحة أسماء واحدة على كل المشاريع، فمزامنة
// مشروع تستولي على سجل مشروع آخر يحمل نفس الاسم. SQLite لا يسمح بتعديل القيد
// عبر ALTER TABLE، فنعيد بناء الجدول.
//
// آمن: ينسخ البيانات كاملة، ويتخطى إن كان الترحيل قد تم.
// الاستخدام: node migrate-memory-scope.js [--db <path>] [--dry-run]

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
const dbPath =
  args.db || p.join(os.homedir(), ".claude", "data", "deepseek.db");
const dryRun = !!args["dry-run"];

if (!fs.existsSync(dbPath)) {
  console.log("لا قاعدة في: " + dbPath + " — لا شيء لترحيله");
  process.exit(0);
}

const db = new DatabaseSync(dbPath);

// هل الترحيل تم؟ نتحقق من نص إنشاء الجدول
const ddl = db
  .prepare(
    "SELECT sql FROM sqlite_master WHERE type='table' AND name='memories'",
  )
  .get();
if (!ddl) {
  console.log("جدول memories غير موجود — لا شيء لترحيله");
  db.close();
  process.exit(0);
}
if (!/name\s+TEXT\s+NOT\s+NULL\s+UNIQUE/i.test(ddl.sql)) {
  console.log("✓ الترحيل تم مسبقاً (التفرّد ليس على name وحده)");
  db.close();
  process.exit(0);
}

const before = db.prepare("SELECT COUNT(*) c FROM memories").get().c;
console.log("سجلات قبل الترحيل: " + before);

// كشف التصادمات: نفس الاسم في نطاقين — لا يمكن أن يحدث تحت القيد القديم،
// لكن نفحص احتياطاً قبل فرض القيد الجديد
const dupes = db
  .prepare(
    "SELECT name, COUNT(*) c FROM memories GROUP BY name, project HAVING c > 1",
  )
  .all();
if (dupes.length) {
  console.error("✗ تصادم أسماء داخل نفس النطاق — عالجه يدوياً أولاً:");
  dupes.forEach((d) => console.error("   " + d.name + " (" + d.c + ")"));
  db.close();
  process.exit(1);
}

if (dryRun) {
  console.log(
    "[معاينة] سيُعاد بناء جدول memories بتفرّد مركّب (name, project)",
  );
  console.log("[معاينة] ستُنقل " + before + " سجلاً كما هي");
  db.close();
  process.exit(0);
}

// الـ views تعتمد على memories فتمنع DROP TABLE — نحفظ تعريفاتها ونعيد بناءها
const views = db
  .prepare("SELECT name, sql FROM sqlite_master WHERE type='view'")
  .all()
  .filter((v) => /\bmemories\b/i.test(v.sql || ""));

try {
  db.exec("BEGIN");
  for (const v of views) db.exec('DROP VIEW IF EXISTS "' + v.name + '"');
  db.exec(`
    CREATE TABLE memories_new (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      type TEXT CHECK(type IN ('user','feedback','project','reference','pattern','tool','session')),
      content TEXT NOT NULL,
      tags TEXT,
      related_memories TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now')),
      usage_count INTEGER DEFAULT 0,
      project TEXT DEFAULT NULL,
      importance TEXT DEFAULT 'long-term' CHECK(importance IN ('permanent','long-term','temporary','expires-soon')),
      trigger TEXT DEFAULT NULL,
      reason TEXT DEFAULT NULL,
      source TEXT DEFAULT NULL,
      status TEXT DEFAULT 'active' CHECK(status IN ('active','outdated','replaced'))
    )
  `);
  db.exec(`
    INSERT INTO memories_new
      (id,name,description,type,content,tags,related_memories,created_at,updated_at,usage_count,project,importance,trigger,reason,source,status)
    SELECT
      id,name,description,type,content,tags,related_memories,created_at,updated_at,usage_count,project,importance,trigger,reason,source,status
    FROM memories
  `);
  db.exec("DROP TABLE memories");
  db.exec("ALTER TABLE memories_new RENAME TO memories");
  db.exec("CREATE INDEX IF NOT EXISTS idx_memories_name ON memories(name)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_memories_type ON memories(type)");
  db.exec(
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_memories_scope ON memories(name, project) WHERE project IS NOT NULL",
  );
  db.exec(
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_memories_scope_global ON memories(name) WHERE project IS NULL",
  );
  for (const v of views) db.exec(v.sql);

  // التحقق قبل COMMIT — بعده يصبح الفشل بلا تراجع ممكن
  const after = db.prepare("SELECT COUNT(*) c FROM memories").get().c;
  if (after !== before) {
    throw new Error("عدد السجلات تغيّر: " + before + " → " + after);
  }

  db.exec("COMMIT");
  console.log("✓ اكتمل الترحيل — " + after + " سجلاً سليماً بتفرّد مركّب");
} catch (e) {
  try {
    db.exec("ROLLBACK");
  } catch (_) {}
  console.error("✗ فشل الترحيل (تراجعت التغييرات): " + e.message);
  db.close();
  process.exit(1);
}

db.close();
