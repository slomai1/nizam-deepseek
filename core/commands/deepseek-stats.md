---
description: لوحة إحصائيات DeepSeek — عرض شامل للإحصائيات من قاعدة SQLite
argument-hint: "[all | tools | sessions | hallucinations | quality]"
---

أنت الآن في وضع **لوحة إحصائيات DeepSeek**. استخدم أداة Bash لتشغيل استعلامات SQLite وعرض النتائج بشكل منظم.

## المطلوب

شغّل الأمر التالي لعرض الإحصائيات الكاملة:

```bash
node -e "
const{DatabaseSync}=require('node:sqlite');
const h=require('os').homedir();
const db=new DatabaseSync(h+'/.claude/data/deepseek.db');

console.log('');
console.log('╔══════════════════════════════════════╗');
console.log('║      🧠 لوحة إحصائيات DeepSeek      ║');
console.log('╚══════════════════════════════════════╝');
console.log('');

// Session stats
try {
  const ses = db.prepare('SELECT COUNT(*)as total, SUM(files_changed)as files, SUM(decisions_count)as decisions, SUM(errors_count)as errors FROM sessions').get();
  if(ses&&ses.total){
    console.log('📊 الجلسات:');
    console.log('  ├─ إجمالي الجلسات: '+ses.total);
    console.log('  ├─ الملفات المعدلة: '+(ses.files||0));
    console.log('  ├─ القرارات: '+(ses.decisions||0));
    console.log('  └─ الأخطاء: '+(ses.errors||0));
    console.log('');
  }
} catch(e) {}

// Tool usage stats
try {
  const tools = db.prepare('SELECT tool_name,COUNT(*)as c,SUM(CASE WHEN success=1 THEN 1 ELSE 0 END)as ok FROM tool_usage GROUP BY tool_name ORDER BY c DESC LIMIT 10').all();
  if(tools.length){
    console.log('🛠️  أكثر الأدوات استخداماً:');
    tools.forEach(t=>{
      const pct = t.c>0?Math.round(t.ok/t.c*100):0;
      const icon = pct>=90?'🟢':pct>=50?'🟡':'🔴';
      console.log('  '+icon+' '+t.tool_name.padEnd(18)+': '+String(t.c).padStart(3)+' مرة | نجاح '+pct+'%');
    });
    console.log('');
  }
} catch(e) {}

// Hallucinations
try {
  const halTotal = db.prepare('SELECT COUNT(*)as c FROM hallucinations').get();
  const halByType = db.prepare('SELECT pattern_type,COUNT(*)as c FROM hallucinations GROUP BY pattern_type ORDER BY c DESC').all();
  console.log('🚨 الهلوسات:');
  console.log('  ├─ الإجمالي: '+(halTotal?.c||0));
  if(halByType.length){
    halByType.forEach(h=>console.log('  ├─ ['+h.pattern_type+']: '+h.c+' مرات'));
    const recent = db.prepare('SELECT pattern_type,hallucinated_value,context,created_at FROM hallucinations ORDER BY created_at DESC LIMIT 5').all();
    console.log('  └─ آخر 5:');
    recent.forEach(r=>console.log('     ['+r.pattern_type+'] '+r.hallucinated_value+' — '+r.context));
  }
  console.log('');
} catch(e) {}

// Memories
try {
  const mem = db.prepare('SELECT COUNT(*)as c FROM memories').get();
  const memByType = db.prepare('SELECT type,COUNT(*)as c FROM memories GROUP BY type').all();
  console.log('📝 الذكريات: '+mem.c);
  if(memByType.length) memByType.forEach(m=>console.log('  ├─ ['+m.type+']: '+m.c));
  console.log('');
} catch(e) {}

// Quality score
console.log('──────────────────────────────────────');
const toolsOk = db.prepare('SELECT SUM(CASE WHEN success=1 THEN 1 ELSE 0 END)as ok, COUNT(*)as total FROM tool_usage').get();
if(toolsOk&&toolsOk.total){
  const score = Math.round(toolsOk.ok/toolsOk.total*100);
  const grade = score>=90?'🏆 ممتاز':score>=70?'👍 جيد':score>=50?'⚠️ متوسط':'🔴 يحتاج تحسين';
  console.log('📈 معدل النجاح: '+score+'% — '+grade);
}
console.log('');
db.close();
"
```

## آرغومنتس

| الأمر | الوصف |
|--------|-------|
| `/deepseek-stats` | لوحة كاملة |
| `/deepseek-stats tools` | استخدام الأدوات فقط |
| `/deepseek-stats sessions` | إحصائيات الجلسات |
| `/deepseek-stats hallucinations` | تقرير الهلوسات |
| `/deepseek-stats quality` | تقييم الجودة |

**ملاحظة:** شغّل الأمر أعلاه مباشرة. البيانات تُقرأ من `~/.claude/data/deepseek.db`
