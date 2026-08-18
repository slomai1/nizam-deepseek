---
name: checklist-ui
description: قائمة فحص جودة الواجهات — تمنع المخرجات النمطية وتضمن التزامن بالمعايير البصرية والتقنية
metadata:
  type: skill
  domain: design, frontend
  priority: high
  version: 1.0
  updated: 2026-07-24
---

# ✅ /checklist-ui — قائمة فحص جودة الواجهات

> استخدم هذا الفحص قبل إنشاء أو تعديل أي واجهة.
> ينطبق على Next.js + WordPress على حد سواء.

**مبدأ العمل:** تمر على المراحل بالترتيب. كل بند إما يُطبق (✓) أو يُشرح لماذا تجاوزته (—).  
**مستوى التفصيل:** اذكر البند + لماذا طبقته أو تجاوزته. لا تحتاج كتابة جمل طويلة.

---

## المرحلة ١ — قبل التصميم (المتطلبات)

- [ ] **هل الـ design موجود أم من الصفر؟**  
  إذا من الصفر → حدد macrostructure الصفحة (hero + features + CTA…)

- [ ] **هل هناك brand موجود؟**  
  ألوان / خطوط / شعار — أو هذه واجهة جديدة بلا brand؟

- [ ] **هل المحتوى حقيقي أم placeholder؟**  
  إذا placeholder → علّمه بـ `[Placeholder]` ولا تخترع أرقامًا أو شهادات

- [ ] **ما هي الشاشة المستهدفة أولاً؟**  
  Desktop / Mobile / كلاهما معًا؟

---

## المرحلة ٢ — الألوان والتباين

- [ ] **نظام الألوان عبر CSS custom properties**  
  ممنوع القيم الخام (raw hex/HSL/RGB) داخل المكونات. كل لون عبر `--color-*`  
  ❌ `#2563eb` ✅ `var(--color-primary)`

- [ ] **التباين ≥ 4.5:1 للنصوص العادية**  
  نصوص صغيرة (body) → 4.5:1  
  نصوص كبيرة (≥ 18px bold / ≥ 24px) → 3:1

- [ ] **OKLCH للألوان** (إن أمكن) بدل HSL/RGB  
  ليس إلزاميًا في WordPress. إلزامي في Next.js إذا تكتب styles من الصفر

- [ ] **النص على الخلفية — قابل للقراءة**  
  لا نص فاتح على خلفية فاتحة، ولا نص غامق على خلفية غامقة

---

## المرحلة ٣ — الطوبوغرافيا (Typography)

- [ ] **العناوين roman (وليست italic)**  
  `font-style: italic` ممنوع في العناوين. فقط للنصوص العادية للتأكيد

- [ ] **العنوان الرئيسي ≤ ٧ كلمات / ≤ ٥٠ حرف**  
  أطول → صغّحجم الخط خطوة

- [ ] **اقتران الخطوط**  
  خط display + خط body. استثناء واحد فقط للـ terminal aesthetic

- [ ] **حماية العناوين الطويلة**  
  `overflow-wrap: anywhere;` و `min-width: 0` على display headers

- [ ] **ارتفاع السطر (line-height)**  
  body: ≥ 1.5 / headings: ≥ 1.2

---

## المرحلة ٤ — التخطيط والاستجابة

- [ ] **ممنوع horizontal scroll**  
  `overflow-x: clip` على `html, body` — وليس `overflow-x: hidden`

- [ ] **شبكات الصور**  
  `minmax(0, 1fr)` — مش `1fr` فقط (يمنع overflow)

- [ ] **رأس القسم ينهار لعمود واحد في الموبايل**  
  Desktop: side-by-side / Mobile: عمود واحد

- [ ] **اختبار ٤ شاشات**  
  320px (موبايل قديم) / 375px (iPhone) / 414px (Android عريض) / 768px (تابلت)

- [ ] **صور مرنة (responsive)**  
  `max-width: 100%; height: auto` على جميع الصور

- [ ] **لا scroll-jumping مع الـ tabs/radio**  
  التبديل بين الأقسام لا يحرّكviewport

---

## المرحلة ٥ — المكونات والتفاعل

- [ ] **٨ حالات تفاعل لكل عنصر تفاعلي**  
  default, hover, `:focus-visible`, `:active`, disabled, loading, error, success  
  في WordPress: الأقل ٤ حالات رئيسية (default, hover, focus, active)

- [ ] **الأزرار بسطر واحد**  
  ممنوع وجود نص يأخذ سطرين في button / nav link / footer link / breadcrumb / CTA

- [ ] **حلقة التركيز (focus ring)**  
  `:focus-visible` بتباين ≥ 3:1 — ممنوع إخفاءها (`outline: none` بدون بديل)

- [ ] **كل الأنيميشن على transform + opacity فقط**  
  لا layout properties (width, height, margin, top, left…)

- [ ] **منحنيات حركة مسمّاة**  
  استخدام `--ease-out`, `--ease-in`, `--ease-in-out`  
  ممنوع `ease` الافتراضي أو bounce/overshoot

- [ ] **دعم reduced motion**  
  `@media (prefers-reduced-motion: reduce)` — الحركة تنهار لـ ≤150ms opacity crossfade

- [ ] **تأخير الـ tooltip**  
  800ms قبل الظهور

---

## المرحلة ٦ — المحظورات (Anti-Patterns)

- [ ] **لا أرقام مزيفة** ("١٠٠٠+ عميل سعيد"، "٩٨٪ رضا")  
  أرقام حقيقية فقط. أو ضع `[رقم حقيقي مطلوب]`

- [ ] **لا كروم مزيف**  
  ممنوع: أشرطة أدوات وهمية، إطارات موبايل وهمية، code-block windows، IDE chrome

- [ ] **لا عناوين قسم مرقّمة بدون داعي**  
  "Chapter 1" أو "Section 02" معطلة إلا إذا المحتوى ترتيبي فعلاً

- [ ] **لا نمط hanging-header (رأس بعمودين)**  
  النمط: "تاج-يسار / عنوان-يمين" ممنوع

- [ ] **لا وحدات مطلقة** (`px`) في أحجام الخطوط  
  استخدم `rem` للـ fonts و `rem`/`em` للتباعد (في الـ CSS)

---

## المرحلة ٧ — النظام القياسي (Design Tokens)

- [ ] **سلم تباعد 4pt / 8pt**  
  قيم التباعد من مضاعفات الرقم الأساسي (4, 8, 12, 16, 24, 32, 48, 64…)  
  بأسماء دلالية: `--space-sm`, `--space-md`, `--space-lg`

- [ ] **متغيرات CSS مسمّاة**  
  `--color-primary` بدل `--color-blue`  
  `--text-display` بدل `--text-3xl`

- [ ] **إضافات ولا استبدالات**  
  في WordPress: أضف للـ stylesheet الموجود — لا تحذف خصائص الثيم الأصلي  
  في Next.js: append للـ global styles

- [ ] **ملف tokens.css (إن أمكن)**  
  جميع الـ tokens في ملف واحد للرجوع والتعديل

---

## المرحلة ٨ — الفحص الذاتي (قبل الإخراج)

قيّم كل بند من ١–٥:

- **الفلسفة** (Philosophy): هل التصميم يحل المشكلة الصحيحة؟
- **التسلسل الهرمي** (Hierarchy): هل المحتوى مرتب حسب الأهمية؟
- **التنفيذ** (Execution): هل الكود نظيف و遵循 المعايير؟
- **الخصوصية** (Specificity): هل يخص هذا المشروع أم قالب عام؟
- **الضبط** (Restraint): هل كل عنصر له غرض؟
- **التنوع** (Variety): هل يختلف عن آخر ٣ واجهات عملتها؟

**القاعدة:**
- أي بند تحت ٣ → يحتاج إعادة نظر قبل الإخراج
- إذا كررت نفس الـ macrostructure لآخر ٣ مرات → غيّره

---

## 📌 خلاصة سريعة (للرجوع السريع)

| المرحلة | التركيز |
|---------|---------|
| ① قبل التصميم | Brand / محتوى / هدف |
| ② الألوان والتباين | Custom properties / OKLCH / 4.5:1 |
| ③ الطوبوغرافيا | Roman headings / ≤٧ كلمات / line-height |
| ④ التخطيط | No scrollbar / 4 شاشات / responsive images |
| ⑤ التفاعل | 8 حالات / focus ring / transform+opacity |
| ⑥ المحظورات | أرقام مزيفة / كروم مزيف / hanging header |
| ⑦ Design tokens | سلم 4pt / أسماء دلالية / tokens.css |
| ⑧ الفحص الذاتي | Score 1-5 / إعادة نظر تحت ٣ |

---

> **ملاحظة:** هذا الـ checklist مبني على مبدأ Hallmark الـ ٥٧ فحصًا مع تكييف لستاك Next.js + WordPress.  
> أنت لست بحاجة لتثبيت Hallmark — هذه القائمة تغطي ٩٠٪ من قيمته العملية.
