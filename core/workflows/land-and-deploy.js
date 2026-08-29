export const meta = {
  name: 'land-and-deploy',
  description: 'دمج PR ← انتظار CI ← نشر Vercel ← تحقق المسارات الحرجة',
  phases: [
    { title: 'دمج', detail: 'دمج Pull Request والتحقق من عدم وجود تعارضات' },
    { title: 'انتظار', detail: 'انتظار اكتمال فحوصات CI' },
    { title: 'نشر', detail: 'نشر إلى Vercel production' },
    { title: 'تحقق', detail: 'فحص المسارات الحرجة بعد النشر' }
  ],
  whenToUse: 'استخدم بعد اكتمال sprint ومراجعة الكود للنشر المباشر'
}

const repo = (args && args.repo) || null
const pullNumber = (args && args.pull_number) || (args && args.pr) || null
const teamId = (args && args.teamId) || null
const projectId = (args && args.projectId) || null
const verifyPaths = (args && args.paths) || ['/']

if (!repo) {
  log('⚠️ مطلوب: repo. استخدم: Workflow({name: "land-and-deploy", args: {repo: "owner/repo"}})')
} else {
  log(`🚀 Land & Deploy: **${repo}**`)
  if (pullNumber) log(`PR: #${pullNumber}`)
}

// ─── Phase 1: دمج ─────────────────────────────────────────────────
phase('دمج')

const mergeResult = await agent(`ادمج Pull Request.

**المستودع**: ${repo}
${pullNumber ? `**رقم PR**: #${pullNumber}` : '**ملاحظة**: لم يحدد رقم PR. ابحث عن آخر PR مفتوح.'}

**الخطوات:**
1. استخدم \`mcp__github__get_pull_request\` لجلب تفاصيل الـ PR
2. تحقق من حالة الـ PR — مفتوح؟ تعارضات؟ مراجعات؟
   - \`mcp__github__get_pull_request_reviews\`
   - \`mcp__github__get_pull_request_status\`
3. إذا كان جاهزاً: \`mcp__github__merge_pull_request\` مع merge_method: "squash"
4. إذا تعارض: \`mcp__github__update_pull_request_branch\` — فإن استمر التعارض، أوقف

**المخرجات:** هل تم الدمج؟ commit SHA؟ تحذيرات`, { label: 'دمج PR' })

log('### 🔀 الدمج')
log(mergeResult || '⚠️ لم يكتمل الدمج')

// ─── Phase 2: انتظار CI ───────────────────────────────────────────
phase('انتظار')

const ciResult = await agent(`انتظر اكتمال فحوصات CI.

**المستودع**: ${repo}

**الخطوات:**
1. \`mcp__github__get_pull_request_status\` لفحص حالة الـ checks
2. حلل كل check: ✅ نجح / ⏳ قيد الانتظار / ❌ فشل
3. اكتفِ بجولة واحدة وأبلغ بالنتيجة

**المخرجات:** حالة CI النهائية — عدد checks الناجحة/الإجمالي — أي أخطاء`, { label: 'فحص CI' })

log('### ⏳ حالة CI')
log(ciResult || '⚠️ لم تصدر حالة')

// ─── Phase 3: نشر ──────────────────────────────────────────────────
phase('نشر')

const deployResult = await agent(`انشر إلى Vercel production.

${teamId && projectId ? `**معلوم**: teamId=${teamId}, projectId=${projectId}` : '**تحتاج لاكتشاف**: teamId و projectId'}

**الخطوات:**
1. اكتشف الـ project:
   ${projectId
    ? `\`mcp__plugin_vercel_vercel__get_project\` مع projectId="${projectId}"`
    : `\`mcp__plugin_vercel_vercel__list_projects\` أو اقرأ \`.vercel/project.json\``}
2. نفّذ النشر: \`mcp__plugin_vercel_vercel__deploy_to_vercel\` مع target: "production"
3. تحقق: \`mcp__plugin_vercel_vercel__get_deployment\`

**المخرجات:** رابط النشر — حالة النشر`, { label: 'نشر Vercel' })

log('### 📦 النشر')
log(deployResult || '⚠️ لم يكتمل النشر')

// ─── Phase 4: تحقق ─────────────────────────────────────────────────
phase('تحقق')

const deployUrl = deployResult && (() => {
  const match = deployResult.match(/https:\/\/[a-zA-Z0-9.-]+\.vercel\.app[^\s]*/)
  return match ? match[0] : null
})()

const pathsToVerify = Array.isArray(verifyPaths) ? verifyPaths : [verifyPaths || '/']

const verifyResult = await agent(`تحقق من أن الموقع يعمل بعد النشر.

${deployUrl ? `**رابط الإنتاج**: ${deployUrl}` : '**ملاحظة**: رابط النشر غير متوفر.'}

**المسارات المطلوب فحصها:**
${pathsToVerify.map((p, i) => `${i + 1}. ${p}`).join('\n')}

**الخطوات باستخدام Playwright MCP:**
1. لكل مسار: \`mcp__playwright__browser_navigate\` إلى المسار
2. لكل صفحة تحقق من:
   - \`browser_console_messages\` (level: "error")
   - \`browser_snapshot\` للعناصر الأساسية
   - \`browser_take_screenshot\` (fullPage: true)
3. تحقق: الصفحة الرئيسية؟ API endpoints؟ الصور والخطوط؟ 404/500؟

**المخرجات:** جدول: مسار | حالة | أخطاء | ملاحظات — ملخص ✅/⚠️/❌`, { label: 'تحقق post-deploy' })

log('### 🔍 التحقق بعد النشر')
log(verifyResult || '⚠️ لم يكتمل التحقق')

// ─── خلاصة ─────────────────────────────────────────────────────────
log('')
log('---')
log('### 🚀 اكتمل Land & Deploy')
log('| المرحلة | النتيجة |')
log('|---------|---------|')
log(`| 🔀 دمج | ${mergeResult ? '✅' : '⚠️'} |`)
log(`| ⏳ CI   | ${ciResult ? '✅' : '⚠️'} |`)
log(`| 📦 نشر  | ${deployResult ? '✅' : '⚠️'} |`)
log(`| 🔍 تحقق | ${verifyResult ? '✅' : '⚠️'} |`)
if (deployUrl) log(`\n🌐 **الموقع**: ${deployUrl}`)
