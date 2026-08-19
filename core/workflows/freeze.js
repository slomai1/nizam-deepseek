export const meta = {
  name: "freeze",
  description:
    "قفل مجلد من التعديل — حماية للمخرجات النهائية. يولد سكريبت للقفل والفك.",
  phases: [
    { title: "فحص", detail: "فحص المجلد المستهدف والمحتوى" },
    { title: "تجميد", detail: "تطبيق القفل وإعداد سكريبت الفك" },
  ],
  whenToUse: "استخدم بعد اكتمال مشروع لمنع التعديل غير المقصود",
};

const target = (args && args.target) || (args && args.path) || null;
const os = (args && args.os) || "windows";

if (!target) {
  log(
    '⚠️ مطلوب: target. استخدم: Workflow({name: "freeze", args: {target: "sub/dir"}})',
  );
  return { status: "aborted", reason: "missing-target" };
}

// ─── حصر النطاق ───────────────────────────────────────────────────
// freeze يجرّد صلاحيات الكتابة عن شجرة كاملة. مسار مطلق أو صاعد يعني
// إمكان تجميد جذر القرص أو مجلد المنزل — نقبل المسارات النسبية فقط.
const unsafe = [
  { test: /^[A-Za-z]:[\\/]/, why: "مسار مطلق على قرص Windows" },
  { test: /^[\\/]/, why: "مسار مطلق من الجذر" },
  { test: /^~/, why: "مسار مجلد المنزل" },
  { test: /(^|[\\/])\.\.([\\/]|$)/, why: "صعود خارج المشروع (..)" },
  { test: /^\$|%[A-Za-z_]+%/, why: "متغيّر بيئة قد يتوسّع لمسار نظام" },
].find((r) => r.test.test(String(target)));

if (unsafe) {
  log("⛔ **مسار مرفوض** — " + unsafe.why);
  log("");
  log(`المسار المطلوب: \`${target}\``);
  log("`freeze` يزيل صلاحية الكتابة عن الشجرة كاملة، فيقتصر على مسار");
  log("نسبي داخل المشروع الحالي حتى لا يُجمَّد قرص أو مجلد منزل بالخطأ.");
  log("");
  log('مثال مقبول: `Workflow({name: "freeze", args: {target: "dist"}})`');
  return { status: "rejected", reason: unsafe.why, target };
}

log(`🧊 Freeze: **${target}** (نسبي إلى مجلد العمل)`);

phase("فحص");

const scanResult = await agent(
  `افحص المجلد قبل التجميد.

**المسار**: ${target}
**النظام**: ${os}

**المطلوب:**
1. تحقق من وجود المجلد
2. أحصِ: عدد الملفات — المجلدات الفرعية — الحجم
3. هل هو git repo؟ submodules؟ symlinks؟
4. أنواع الملفات الرئيسية

**المخرجات:** إحصائيات — تحذيرات — توصية`,
  { label: "فحص المجلد" },
);

log("### 📂 فحص المجلد");
log(scanResult || "⚠️ لم يكتمل الفحص");

phase("تجميد");

const freezeResult = await agent(
  `نفّذ تجميد المجلد.

**المسار**: ${target}
**النظام**: ${os}

**الخطوات حسب النظام:**

### Windows (PowerShell):
1. احفظ ACL الحالية: \`Get-Acl "${target}" | Export-Clixml "${target}.acl-backup.xml"\`
2. اجعل القراءة فقط للمستخدم الحالي
3. أنشئ \`${target}.unfreeze.ps1\` لاستعادة الصلاحيات
4. أنشئ \`${target}.refreeze.ps1\` لإعادة القفل

### Unix/Linux:
1. \`chmod -R a-w "${target}"\`
2. أنشئ \`${target}.unfreeze.sh\`

**المخرجات:**
1. تأكيد نجاح القفل
2. مسار سكريبت الفك
3. أي تحذيرات`,
  { label: "تنفيذ التجميد" },
);

log("### 🧊 نتيجة التجميد");
log(freezeResult || "⚠️ لم يكتمل التجميد");
log("");
log("---");
log(`🧊 Freeze اكتمل — ${target}`);
