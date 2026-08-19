#!/usr/bin/env node
// استعلام الذاكرة — قراءة فقط، استعلامات ثابتة، لا إدخال يدخل الكود
//
//   node mem-query.js            لوحة الإحصائيات
//   node mem-query.js 1..5       استعلام جاهز بالرقم
//
// لا يقبل SQL حراً: الإدخال يُقرأ كرقم فقط، والاستعلامات ثابتة في الكود،
// والقاعدة تُفتح للقراءة فقط.

const os = require("os");
const p = require("path");
const { DatabaseSync } = require("node:sqlite");

const QUERIES = {
  1: {
    label: "أكثر الأدوات استخداماً",
    sql: "SELECT tool_name, COUNT(*) c, SUM(CASE WHEN success=1 THEN 1 ELSE 0 END) ok FROM tool_usage GROUP BY tool_name ORDER BY c DESC",
  },
  2: {
    label: "الهلوسات المتكررة",
    sql: "SELECT * FROM v_frequent_hallucinations",
  },
  3: { label: "آخر الذكريات", sql: "SELECT * FROM v_recent_memories" },
  4: { label: "إحصائيات الجلسات", sql: "SELECT * FROM v_session_stats" },
  5: {
    label: "الذكريات مرتبة بالتاريخ",
    sql: "SELECT name, type, project, description, created_at FROM memories ORDER BY created_at DESC",
  },
};

const dbPath = p.join(os.homedir(), ".claude", "data", "deepseek.db");

let db;
try {
  db = new DatabaseSync(dbPath, { readOnly: true });
} catch (e) {
  console.error("تعذّر فتح قاعدة الذاكرة: " + e.message);
  process.exit(1);
}

// الإدخال يُقرأ كرقم فقط — أي شيء آخر يُهمل
// argv[2] لأن هذا ملف سكربت (في وضع node -e يكون argv[1]، وهو فرق يُخطئ فيه كثيرون)
const raw = process.argv[2] || "";
const n = Number(String(raw).replace(/[^0-9]/g, ""));

try {
  if (n && QUERIES[n]) {
    console.log("# " + QUERIES[n].label + "\n");
    console.log(JSON.stringify(db.prepare(QUERIES[n].sql).all(), null, 2));
  } else if (raw && !n) {
    console.error("رقم استعلام غير صالح. المتاح:");
    Object.entries(QUERIES).forEach(([k, v]) =>
      console.error("  " + k + " — " + v.label),
    );
    process.exit(1);
  } else {
    // لوحة الإحصائيات
    const one = (sql) => {
      try {
        return db.prepare(sql).get().c;
      } catch (e) {
        return "?";
      }
    };
    console.log("📊 لوحة الذاكرة\n");
    console.log("  ذكريات:        " + one("SELECT COUNT(*) c FROM memories"));
    console.log(
      "    ├─ عامة:     " +
        one("SELECT COUNT(*) c FROM memories WHERE project IS NULL"),
    );
    console.log(
      "    └─ مشاريع:   " +
        one("SELECT COUNT(*) c FROM memories WHERE project IS NOT NULL"),
    );
    console.log("  جلسات:         " + one("SELECT COUNT(*) c FROM sessions"));
    console.log(
      "  هلوسات:        " + one("SELECT COUNT(*) c FROM hallucinations"),
    );
    console.log("  قرارات:        " + one("SELECT COUNT(*) c FROM decisions"));
    console.log(
      "  تغييرات ملفات: " + one("SELECT COUNT(*) c FROM file_changes"),
    );
    console.log("  استخدام أدوات: " + one("SELECT COUNT(*) c FROM tool_usage"));
    try {
      const rows = db
        .prepare(
          "SELECT project, COUNT(*) c FROM memories WHERE project IS NOT NULL GROUP BY project ORDER BY c DESC LIMIT 8",
        )
        .all();
      if (rows.length) {
        console.log("\n  حسب المشروع:");
        rows.forEach((r) => console.log("    " + r.project + ": " + r.c));
      }
    } catch (e) {
      /* لا شيء */
    }
    console.log("\n  استعلامات جاهزة: node mem-query.js 1..5");
  }
} catch (e) {
  console.error("خطأ: " + e.message);
  process.exit(1);
} finally {
  db.close();
}
