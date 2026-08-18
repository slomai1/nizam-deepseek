export const meta = {
  name: "sprint",
  description:
    "خط أنابيب كامل: مواصفات → تخطيط → بناء → مراجعة → تدقيق → شحن. يضبط نفسه حسب حجم المهمة (small/medium/large/sensitive)",
  phases: [
    { title: "مواصفات", detail: "تحديد المتطلبات والنطاق" },
    { title: "تخطيط", detail: "وضع خطة تنفيذ بمراحل واضحة" },
    { title: "بناء", detail: "التنفيذ بواسطة وكيل متخصص" },
    { title: "مراجعة", detail: "مراجعة عميقة للتغييرات" },
    { title: "تدقيق", detail: "فحص الجودة وإعادة التحقق" },
    { title: "شحن", detail: "فحص الجاهزية النهائية" },
  ],
  whenToUse:
    "استخدم هذا workflow لكل مهمة تطوير غير تافهة — يوحد كل المراحل في مسار واحد بدل تشغيل كل مرحلة يدوياً",
};

// ─── إعداد ─────────────────────────────────────────────────────────
const taskInput = (() => {
  if (typeof args === "string") return args;
  if (args && typeof args === "object")
    return args.task || JSON.stringify(args);
  return null;
})();

const taskSize = (args && args.size) || "medium";
const existingSpec = (args && args.spec) || null;
const forceAgent = (args && args.agent) || null;

// أي المراحل نشغّل حسب حجم المهمة
const PHASE_MAP = {
  small: ["build", "review"],
  medium: ["plan", "build", "review"],
  large: ["plan", "build", "review", "qa"],
  sensitive: ["plan", "build", "review", "qa", "ship"],
};
const activePhases = PHASE_MAP[taskSize] || PHASE_MAP.medium;

// مستوى جهد المراجعة حسب حجم المهمة
const EFFORT_MAP = {
  small: "medium",
  medium: "high",
  large: "high",
  sensitive: "max",
};
const reviewEffort = EFFORT_MAP[taskSize] || "high";

if (!taskInput) {
  log(
    '⚠️ لا توجد مهمة محددة. استخدم: Workflow({name: "sprint", args: {task: "وصف المهمة", size: "medium"}})',
  );
} else {
  log(`🏃 Sprint: **${taskInput}**`);
  log(`الحجم: \`${taskSize}\` ← phases: ${activePhases.join(" → ")}`);
  if (existingSpec) log("📋 سيستخدم المواصفات الموجودة مسبقاً");
}

// ─── Phase: مواصفات ───────────────────────────────────────────────
// تُشغّل فقط إذا كان عندنا plan (أي medium فما فوق) ولا يوجد spec مسبق
if (activePhases.includes("plan") && !existingSpec) {
  phase("مواصفات");

  const spec = await agent(
    `أنت محلل متطلبات. مهمتك تحديد نطاق المهمة التالية بدقة قبل التخطيط.

**المهمة المطلوبة:**
${taskInput}

**السياق:**
- افحص الملفات المحيطة بالمشروع (package.json, composer.json, أي ملفات تكوين)
- اقرأ PRODUCT.md أو README إن وُجد
- افحص git log لآخر 5 تغييرات
- حدد التقنية المستخدمة (Next.js, WordPress, Flutter, Python, ...)

**المطلوب منك — تقرير مواصفات مختصر (لا تتجاوز 300 كلمة):**

1. **الهدف**: ماذا نحاول تحقيقه بالضبط؟
2. **النطاق الحالي**: ما الذي سينفذ الآن (وليس لاحقاً)؟
3. **خارج النطاق**: ما الذي لن ندخله في هذه المرحلة؟
4. **الملفات المتأثرة**: الملفات الرئيسية التي ستتغير (من فحصك للكود)
5. **المخاطر**: نقطة أو نقطتا خطر محتملتان
6. **المسار التقني**: ما التقنية/الـ stack المستخدمة؟

أخرج التقرير بصيغة واضحة. كن دقيقاً — هذا سيسلّم للمرحلة التالية مباشرة.`,
    { label: "تحديد المواصفات" },
  );

  log("### 📋 المواصفات");
  log(spec || "⚠️ لم تنتج مواصفات");
}

// ─── Phase: تخطيط ─────────────────────────────────────────────────
if (activePhases.includes("plan")) {
  phase("تخطيط");

  const planContext =
    existingSpec || (typeof spec !== "undefined" ? spec : taskInput);

  const planResult = await agent(
    `أنت مهندس برمجيات. ضع خطة تنفيذ دقيقة للمهمة.

**المواصفات:**
${planContext}

**المطلوب — خطة تنفيذ من 4 أقسام:**

### 1. مسار التنفيذ (خطوات مرقمة)
- قسّم المهمة إلى خطوات صغيرة (5-10 خطوات)
- كل خطوة: ماذا سيُفعل + في أي ملف
- رتّب الخطوات حسب التبعية

### 2. الوكيل المتخصص
اختر الوكيل المناسب للتنفيذ من القائمة (اختر واحداً فقط):
- \`nextjs-developer\` — إذا كان المشروع Next.js / React / TypeScript
- \`wordpress-master\` — إذا كان WordPress / PHP
- \`flutter-expert\` — إذا كان Flutter / Dart
- \`python-pro\` — إذا كان Python / FastAPI / Django
- \`frontend-developer\` — إذا كان واجهات HTML/CSS/JS عامة
- \`backend-developer\` — إذا كان API / خادم / بنية تحتية
- \`fullstack-developer\` — إذا كان Full-stack

اذكر اسم الوكيل بسطر منفصل: \`agent: <اسم-الوكيل>\`

### 3. نقاط التحقق
- كيف سنعرف أن التنفيذ ناجح؟ (2-3 معايير)

### 4. تحذيرات
- ما الذي يجب الحذر منه أثناء التنفيذ؟`,
    { label: "تخطيط التنفيذ" },
  );

  log("### 🗺️ خطة التنفيذ");
  log(planResult || "⚠️ لم تنتج خطة");

  // استخراج الوكيل الموصى به
  const agentMatch = planResult && planResult.match(/agent:\s*([a-z-]+)/i);
  const recommendedAgent =
    forceAgent || (agentMatch ? agentMatch[1].trim() : null);
  if (recommendedAgent) log(`\n🤖 الوكيل الموصى به: \`${recommendedAgent}\``);
}

// ─── Phase: بناء ───────────────────────────────────────────────────
if (activePhases.includes("build")) {
  phase("بناء");

  const buildContext =
    (typeof planResult !== "undefined" ? planResult : null) ||
    existingSpec ||
    taskInput;
  const builderAgent =
    forceAgent ||
    (typeof recommendedAgent !== "undefined" ? recommendedAgent : null) ||
    "general-purpose";

  log(`🔨 تنفيذ بواسطة: \`${builderAgent}\``);

  const buildResult = await agent(
    `نفّذ المهمة التالية. اقرأ الخطة أولاً ثم نفّذها خطوة بخطوة.

**المهمة:** ${taskInput}

**الخطة والمواصفات:**
${buildContext}

**قواعد التنفيذ:**
1. اقرأ الملفات قبل تعديلها
2. عدّل فقط ما هو مطلوب — لا تلمس شيئاً خارج النطاق
3. طابق أسلوب الكود الموجود في المشروع
4. بعد كل تعديل، تحقق من عدم وجود أخطاء
5. إذا واجهت مشكلة، أوقف وبلّغ — لا تخمّن

**المخرجات المطلوبة بعد التنفيذ:**
- قائمة الملفات التي عُدّلت (مع عدد الأسطر المضافة/المحذوفة)
- أي تحذيرات أو ملاحظات
- هل كل نقاط التحقق من الخطة تحققت؟`,
    {
      label: "تنفيذ البناء",
      agentType: builderAgent === "general-purpose" ? undefined : builderAgent,
    },
  );

  log("### 🔨 نتيجة البناء");
  log(buildResult || "⚠️ لم تنتج نتيجة");
}

// ─── Phase: مراجعة ─────────────────────────────────────────────────
if (activePhases.includes("review")) {
  phase("مراجعة");

  log("🔍 تشغيل deep-review...");
  const reviewResult = await workflow("deep-review", { effort: reviewEffort });

  log("### ✅ المراجعة");
  log(typeof reviewResult === "string" ? reviewResult : "✅ اكتملت المراجعة");
}

// ─── Phase: تدقيق ──────────────────────────────────────────────────
if (activePhases.includes("qa")) {
  phase("تدقيق");

  log("🧪 تشغيل auto-verify...");
  const qaResult = await workflow("auto-verify");

  log("### 🧪 التدقيق");
  log(typeof qaResult === "string" ? qaResult : "✅ اكتمل التدقيق");
}

// ─── Phase: شحن ────────────────────────────────────────────────────
if (activePhases.includes("ship")) {
  phase("شحن");

  const shipReport = await agent(
    `افحص جاهزية المشروع للشحن. تحقق من:
- هل جميع المراحل السابقة اكتملت بنجاح؟
- هل هناك مخاطر regression غير محلولة؟
- هل هناك حاجة لتحديث التوثيق؟
- هل المخرجات تطابق المواصفات الأصلية؟

أخرج تقريراً بهذا الشكل:
- **plan**: تم / جزئي / غير مطلوب
- **build**: تم / جزئي
- **review**: اجتاز / معلق / فشل / غير مطلوب
- **qa**: اجتاز / معلق / فشل / غير مطلوب
- **مخاطر regression**: منخفض / متوسط / مرتفع
- **التوثيق**: محدّث / غير مطلوب / معلق
- **قيود معروفة**: لا يوجد / (أذكرها إن وجدت)`,
    { label: "فحص الجاهزية" },
  );

  log("### 🚢 تقرير الجاهزية النهائية");
  log(shipReport || "⚠️ لم يصدر تقرير");
}

// ─── خلاصة ─────────────────────────────────────────────────────────
log("");
log("---");
log(`🏁 Sprint اكتمل — \`${taskSize}\` — ${activePhases.join(" → ")}`);
