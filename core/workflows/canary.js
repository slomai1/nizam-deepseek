export const meta = {
  name: 'canary',
  description: 'مراقبة ما بعد النشر — تتبع أخطاء Vercel والتنبيه عند وجود مشاكل',
  phases: [
    { title: 'فحص', detail: 'سحب أخطاء runtime من Vercel' },
    { title: 'تحليل', detail: 'تحليل الأنماط وتصنيف الخطورة' },
    { title: 'تنبيه', detail: 'تقرير وتنبيه عند الحاجة' }
  ],
  whenToUse: 'شغّل بعد land-and-deploy للمراقبة — أو دورياً كل 30 دقيقة بعد النشر'
}

const projectId = (args && args.projectId) || null
const teamId = (args && args.teamId) || null
const since = (args && args.since) || '1h'

if (!projectId) {
  log('⚠️ مطلوب: projectId. استخدم: Workflow({name: "canary", args: {projectId: "prj_xxx"}})')
} else {
  log(`🐤 Canary: مراقبة ${projectId} — آخر ${since}`)
}

phase('فحص')

const errorsResult = await agent(`اسحب أخطاء runtime من Vercel.

**المشروع**: ${projectId}
**الفترة**: آخر ${since}

**الخطوات:**
1. \`mcp__plugin_vercel_vercel__get_runtime_errors\`
   - projectId: "${projectId}"
   - teamId: "${teamId || ''}"
   - since: "${since}"

2. حلل:
   - عدد الـ error clusters
   - الخطأ الأكثر تكراراً
   - أي spike مفاجئ؟
   - routes جديدة متأثرة؟

**المخرجات:** عدد الأخطاء — أعلى 3 أنواع — مقارنة بالفترة السابقة`, { label: 'سحب أخطاء Vercel' })

log('### 🐛 أخطاء Runtime')
log(errorsResult || '✅ لا توجد أخطاء — أو تعذر السحب')

phase('تحليل')

const analysisResult = await agent(`حلل الأخطاء واكتشف الأنماط.

**نتائج الفحص:**
${errorsResult || 'لا توجد أخطاء'}

**الخطوات:**
1. صنف حسب: الخطورة (fatal/error/warning) — المصدر (serverless/edge/static) — الـ route
2. ابحث عن: أخطاء جديدة بعد آخر نشر؟ زيادة في المعدل؟ تجمع زمني؟
3. إن أمكن: \`mcp__plugin_vercel_vercel__get_runtime_logs\` لعينة 3-5 أخطاء

**المخرجات:** تصنيف — أنماط/spikes — توصية: تجاهل/مراقبة/تدخل`, { label: 'تحليل الأنماط' })

log('### 📊 تحليل الأنماط')
log(analysisResult || '⚠️ لم يكتمل التحليل')

phase('تنبيه')

const alertResult = await agent(`أصدر تقرير Canary نهائي.

**التحليل:** ${analysisResult || 'غير متوفر'}
**الأخطاء:** ${errorsResult || 'غير متوفرة'}

**المطلوب:**
1. **حالة عامة**: 🟢 صحي / 🟡 تحذير / 🔴 خطر
2. **مؤشرات**: إجمالي الأخطاء — معدل لكل ألف طلب — أعلى route متأثر
3. **توصية**: 🟢 لا إجراء / 🟡 مراقبة 30د / 🔴 تحقيق فوري
4. **إجراءات**: rollback؟ issue؟ إعادة canary؟`, { label: 'تقرير المراقبة' })

log('### 🐤 تقرير Canary')
log(alertResult || '⚠️ لم يصدر تقرير')
log('')
log('---')
log(`🐤 Canary اكتمل — ${since} — ${projectId || ''}`)
