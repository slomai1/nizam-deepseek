export const meta = {
  name: 'code-quality-pipeline',
  description: 'خط أنابيب جودة متسلسل: تعقيد ← تكرار ← تغطية ← أسلوب ← تقييم نهائي',
  phases: [
    { title: 'تعقيد', detail: 'تحليل التعقيد ودالة الحجم' },
    { title: 'تكرار', detail: 'اكتشاف الكود المنسوخ' },
    { title: 'أسلوب', detail: 'تدقيق الأسلوب والاتساق' },
    { title: 'تقييم', detail: 'درجة الجودة النهائية' }
  ]
}

const TARGET = typeof args === 'string' ? args : (process.env.TARGET || '.')

phase('تعقيد')
const complexity = await agent(`حلل تعقيد الكود. لكل ملف/دالة، احسب:
- عدد الأسطر (كبير جداً = أكثر من 200 سطر)
- التعقيد الحلقي (cyclomatic complexity) التقديري
- عدد المعاملات (أكثر من 4 = مشكلة)
- مستوى التداخل (nesting > 3 = مشكلة)
- التبعيات الخارجية

الكود: ${TARGET}`, { label: 'تحليل التعقيد' })

phase('تكرار')
const duplication = await agent(`ابحث عن أنماط التكرار في الكود:
- كتل متشابهة (حتى مع اختلاف طفيف في المتغيرات)
- منطق مكرر بين ملفات مختلفة
- دوال يمكن دمجها
- ثوابت أو strings مكررة

الكود: ${TARGET}`, { label: 'كشف التكرار' })

phase('أسلوب')
const style = await agent(`دقق أسلوب الكود:
- هل التسميات واضحة ومعبرة؟
- هل التعليقات مفيدة وموجودة عند الحاجة؟
- هل التنسيق متسق؟
- هل الأنماط (patterns) متسقة عبر الملفات؟
- هل هناك تعليقات قديمة أو مضللة؟

الكود: ${TARGET}`, { label: 'تدقيق الأسلوب' })

phase('تقييم')
const qualityScore = await agent(`بناءً على التحليلات السابقة، أعط درجة جودة نهائية من 100:

- التعقيد (30 نقطة): ${complexity || 'غير متوفر'}
- التكرار (25 نقطة): ${duplication || 'غير متوفر'}
- الأسلوب (25 نقطة): ${style || 'غير متوفر'}
- التقدير العام (20 نقطة)

أخرج النتيجة بصيغة JSON:
{
  "totalScore": 0-100,
  "categories": {
    "complexity": {"score": 0-30, "issues": [...]},
    "duplication": {"score": 0-25, "issues": [...]},
    "style": {"score": 0-25, "issues": [...]},
    "overall": {"score": 0-20, "notes": "..."}
  },
  "topIssues": [...],
  "recommendation": "merge-ready | needs-work | critical-issues"
}`, { label: 'تقييم نهائي', schema: undefined })

log('# 📐 خط أنابيب الجودة')
log(`**الهدف**: ${TARGET}`)
log('')
log('## 🧮 التعقيد')
log(complexity || 'لا توجد نتائج')
log('')
log('## 📋 التكرار')
log(duplication || 'لا توجد نتائج')
log('')
log('## ✍️ الأسلوب')
log(style || 'لا توجد نتائج')
log('')
log('## 🏆 التقييم النهائي')
log(qualityScore || 'لا يوجد تقييم')
log('')
log('---')
log('📐 اكتمل خط أنابيب الجودة')
