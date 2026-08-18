export const meta = {
  name: 'freeze',
  description: 'قفل مجلد من التعديل — حماية للمخرجات النهائية. يولد سكريبت للقفل والفك.',
  phases: [
    { title: 'فحص', detail: 'فحص المجلد المستهدف والمحتوى' },
    { title: 'تجميد', detail: 'تطبيق القفل وإعداد سكريبت الفك' }
  ],
  whenToUse: 'استخدم بعد اكتمال مشروع لمنع التعديل غير المقصود'
}

const target = (args && args.target) || (args && args.path) || null
const os = (args && args.os) || 'windows'

if (!target) {
  log('⚠️ مطلوب: target. استخدم: Workflow({name: "freeze", args: {target: "/path"}})')
} else {
  log(`🧊 Freeze: **${target}**`)
}

phase('فحص')

const scanResult = await agent(`افحص المجلد قبل التجميد.

**المسار**: ${target}
**النظام**: ${os}

**المطلوب:**
1. تحقق من وجود المجلد
2. أحصِ: عدد الملفات — المجلدات الفرعية — الحجم
3. هل هو git repo؟ submodules؟ symlinks؟
4. أنواع الملفات الرئيسية

**المخرجات:** إحصائيات — تحذيرات — توصية`, { label: 'فحص المجلد' })

log('### 📂 فحص المجلد')
log(scanResult || '⚠️ لم يكتمل الفحص')

phase('تجميد')

const freezeResult = await agent(`نفّذ تجميد المجلد.

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
3. أي تحذيرات`, { label: 'تنفيذ التجميد' })

log('### 🧊 نتيجة التجميد')
log(freezeResult || '⚠️ لم يكتمل التجميد')
log('')
log('---')
log(`🧊 Freeze اكتمل — ${target}`)
