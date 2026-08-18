---
description: تحميل الذاكرة في بداية الجلسة — فهرس + إحصائيات + تحذيرات
argument-hint: ""
---

أنت الآن في وضع **تحميل الذاكرة**. اعرض حالة نظام الذاكرة بالكامل.

## آلية التحميل 🧠

### الخطوة 1: قراءة الفهرس

اقرأ `~/.claude/projects/<معرّف-مشروعك>/memory/MEMORY.md` واعرض:

- عدد ملفات الذاكرة
- آخر تحديث
- قائمة المشاريع النشطة

### الخطوة 2: فحص سلامة المسار

تحقق من وجود الملفات المذكورة في MEMORY.md فعلياً على القرص:

```
ls ~/.claude/projects/<معرّف-مشروعك>/memory/*.md | wc -l
```

### الخطوة 3: إحصائيات SQLite

شغّل هذا الاستعلام عبر node:

```bash
node -e "
const {DatabaseSync}=require('node:sqlite');
const h=require('os').homedir();
const db=new DatabaseSync(h+'/.claude/data/deepseek.db');
try {
  const mem=db.prepare('SELECT COUNT(*)as c FROM memories').get();
  const ses=db.prepare('SELECT COUNT(*)as c FROM sessions').get();
  const hal=db.prepare('SELECT COUNT(*)as c FROM hallucinations').get();
  const last=db.prepare('SELECT MAX(started_at) as last FROM sessions').get();
  console.log('sessions:'+ses.c+'|memories:'+mem.c+'|hallucinations:'+hal.c+'|last_session:'+(last.last||'never'));
} catch(e) { console.log('error:'+e.message); }
db.close();
"
```

### الخطوة 4: تحذيرات

اعرض تنبيهات لأي من هذه الحالات:

- `hallucinations = 0` ← "⚠️ سجل الهلوسات فارغ — لم تُسجل أي هلوسة بعد"
- `last_session > 7 أيام` ← "⚠️ آخر جلسة مسجلة منذ X يوم"
- `memories < 10` ← "⚠️ عدد الذكريات منخفض"
- `v_stale_memories` فارغ ← "⚠️ آلية تنظيف الذاكرة معطلة"

### الخطوة 5: المخرجات النهائية

اعرض ملخصاً بهذا التنسيق:

```
🧠 الذاكرة جاهزة
   ├─ Markdown: X ملف | آخر تحديث: YYYY-MM-DD
   ├─ SQLite: X صف | جلسات: X | هلوسات: X
   ├─ المشاريع: [قائمة]
   ├─ آخر جلسة: YYYY-MM-DD (منذ X يوم)
   └─ تنبيهات: [قائمة التحذيرات]
```
