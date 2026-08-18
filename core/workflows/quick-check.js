export const meta = {
  name: "quick-check",
  description:
    "فحص سريع: مراجعة الكود + أمان — مع دعم مستويين للجهد (low/high)",
  phases: [
    { title: "مراجعة", detail: "مراجعة التغييرات" },
    { title: "أمان", detail: "فحص أمني" },
    { title: "تقرير", detail: "تجميع النتائج" },
  ],
};

const DIFF = "git diff --name-only HEAD~1";
const effort = (typeof args === "object" && args?.effort) || "low";
const useSpecialist = effort === "high";

phase("مراجعة");
const review = await agent(
  `راجع التغييرات الحالية. ركز على:
- الأخطاء المنطقية
- تحسينات الأداء
- تكرار الكود
استخدم: ${DIFF}`,
  {
    label: "مراجعة الكود",
    agentType: useSpecialist ? "code-reviewer" : undefined,
  },
);

phase("أمان");
const security = await agent(
  `افحص التغييرات أمنياً. ركز على:
- المفاتيح والبيانات الحساسة
- ثغرات injection
- التحقق من المدخلات
استخدم: ${DIFF}`,
  {
    label: "فحص أمني",
    agentType: useSpecialist ? "security-auditor" : undefined,
  },
);

phase("تقرير");
log("## تقرير الفحص السريع");
log(`**مستوى الجهد:** \`${effort}\``);
log("### مراجعة الكود");
log(review || "لا توجد ملاحظات");
log("### الفحص الأمني");
log(security || "لا توجد مشاكل أمنية");
log("---");
log("تم الفحص السريع ✓");
