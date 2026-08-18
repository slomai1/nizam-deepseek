---
description: استعلام الذاكرة — بحث نصي أو إحصائيات أو SQL مباشر
argument-hint: "[stats | <كلمة بحث> | sql <استعلام>]"
---

أنت الآن في وضع **استعلام الذاكرة**. ابحث أو استعلم بالطريقة المناسبة.

المتغير: `$ARGUMENTS`

## آلية الاستعلام 🔍

### إذا كان `stats` أو فارغ — لوحة الإحصائيات

شغّل عبر node:

```bash
node -e "
const {DatabaseSync}=require('node:sqlite');
const h=require('os').homedir();
const db=new DatabaseSync(h+'/.claude/data/deepseek.db');

try {
  // إحصائيات عامة
  const mem=db.prepare('SELECT COUNT(*)as c FROM memories').get();
  const ses=db.prepare('SELECT COUNT(*)as c FROM sessions').get();
  const hal=db.prepare('SELECT COUNT(*)as c FROM hallucinations').get();
  const dec=db.prepare('SELECT COUNT(*)as c FROM decisions').get();
  const fc=db.prepare('SELECT COUNT(*)as c FROM file_changes').get();
  const tu=db.prepare('SELECT COUNT(*)as c FROM tool_usage').get();

  // آخر جلسة
  const last=db.prepare(\"SELECT MAX(started_at) as d FROM sessions\").get();

  // أكثر 5 أدوات استخداماً
  const tools=db.prepare('SELECT tool_name,COUNT(*)c,SUM(CASE WHEN success=1 THEN 1 ELSE 0 END)ok FROM tool_usage GROUP BY tool_name ORDER BY c DESC LIMIT 5').all();

  // المشاريع
  const proj=db.prepare('SELECT * FROM v_session_stats').all();

  console.log('GENERAL|'+mem.c+'|'+ses.c+'|'+hal.c+'|'+dec.c+'|'+fc.c+'|'+tu.c+'|'+(last?.d||'never'));
  console.log('TOOLS|'+JSON.stringify(tools));
  console.log('PROJECTS|'+JSON.stringify(proj));
} catch(e) { console.log('ERROR|'+e.message); }
db.close();
"
```

اعرض النتائج بهذا التنسيق:

```
📊 لوحة الإحصائيات
   ├─ 🗄️ SQLite: X ذاكرة | X جلسة | X قرار | X تغيير ملف | X استخدام أداة
   ├─ 🚨 هلوسات مسجلة: X (منذ البدء)
   ├─ 📅 آخر جلسة: YYYY-MM-DD (منذ X يوم)
   ├─ 🔧 أكثر الأدوات:
   │   ├─ tool1: X (نجاح Y%)
   │   ├─ tool2: X (نجاح Y%)
   │   └─ tool3: X (نجاح Y%)
   └─ 📁 المشاريع:
       ├─ project1: X جلسات, X ملفات
       └─ project2: X جلسات, X ملفات
```

### إذا كان كلمة بحث — بحث في Markdown

1. استخدم Glob: `*.md` في `~/.claude/projects/<معرّف-مشروعك>/memory/`
2. ثم Grep عن `$ARGUMENTS` في الملفات
3. اعرض النتائج:

```
🔍 نتائج البحث عن "$ARGUMENTS"
   ├─ file1.md — [الوصف] — صلة: [لماذا]
   ├─ file2.md — [الوصف] — صلة: [لماذا]
   └─ file3.md — [الوصف] — صلة: [لماذا]
```

### إذا كان `sql <رقم>` — استعلام جاهز آمن (قراءة فقط)

نفّذ الاستعلام الجاهز المقابل من القائمة الثابتة. **لا يُحقن أي SQL حر** — الرقم فقط يُقبل، والاستعلامات بيضاء ثابتة، والقاعدة تُفتح للقراءة فقط:

```bash
node -e "
const {DatabaseSync}=require('node:sqlite');
const h=require('os').homedir();
const db=new DatabaseSync(h+'/.claude/data/deepseek.db',{readOnly:true});
try {
  // نستخرج الرقم فقط من الإدخال (مثل 'sql 3') — لا يُقبل SQL حر إطلاقاً
  const q = Number(String('$ARGUMENTS').replace(/[^0-9]/g, '')) || 0;
  const QUERIES = {
    1: \"SELECT tool_name, COUNT(*) c, SUM(CASE WHEN success=1 THEN 1 ELSE 0 END) ok FROM tool_usage GROUP BY tool_name ORDER BY c DESC\",
    2: 'SELECT * FROM v_frequent_hallucinations',
    3: 'SELECT * FROM v_recent_memories',
    4: 'SELECT * FROM v_session_stats',
    5: 'SELECT name, description, type, created_at FROM memories ORDER BY created_at DESC'
  };
  const sql = QUERIES[q];
  if (!sql) { console.log('ERROR: رقم استعلام غير صالح — استخدم 1 إلى 5'); process.exit(0); }
  const r = db.prepare(sql).all();
  console.log(JSON.stringify(r, null, 2));
} catch(e) { console.log('ERROR: '+e.message); }
db.close();
"
```

**الاستعلامات الجاهزة:**

```
/mem-query sql 1   أكثر الأدوات استخداماً
/mem-query sql 2   الهلوسات المتكررة
/mem-query sql 3   آخر الذكريات
/mem-query sql 4   إحصائيات الجلسات
/mem-query sql 5   الذكريات مرتبة بالتاريخ
```
