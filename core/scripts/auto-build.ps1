<#
.SYNOPSIS
  يبني مشروعًا كاملًا من خطة — يشتغل في الخلفية بدون تدخلك
.DESCRIPTION
  يقرأ وصف المشروع، يولّد خطة تفصيلية، يشغّل Claude Code في الخلفية،
  ويراقب التقدم. تقدر تقفل التيرمنال وترجع بعدين تشوف النتيجة.

.PARAMETER ProjectDir
  مسار مجلد المشروع (الافتراضي: المجلد الحالي)
.PARAMETER Description
  وصف المشروع — وش تبي تسوي بالضبط
.PARAMETER DescriptionFile
  ملف فيه وصف المشروع (بديل عن Description)
.PARAMETER PlanFile
  اسم ملف الخطة (الافتراضي: PLAN.md)
.PARAMETER LogFile
  اسم ملف السجل (الافتراضي: auto-build-log.txt)
.PARAMETER ProgressFile
  اسم ملف التقدم (الافتراضي: progress.md)
.PARAMETER MaxSteps
  أقصى عدد خطوات (الافتراضي: 20 — إرشادي، لا يمنع التجاوز برمجيًا)
.PARAMETER TimeoutMinutes
  كم دقيقة قبل قطع الشغل (الافتراضي: 480 = 8 ساعات — يُطبَّق مع -Monitor)
.PARAMETER Monitor
  شغّل وضع المراقبة بعد بدء البناء
.PARAMETER RunChecklist
  طبّق فحص checklist-ui على كل واجهة أثناء البناء
.PARAMETER LoopReady
  جهّز ملفات Loop Engineering بعد اكتمال المشروع

.EXAMPLE
  # من مجلد المشروع
  .\auto-build.ps1 -Description "موقع محاماة: صفحة رئيسية + تواصل + من نحن"

.EXAMPLE
  # مع ملف وصف + مراقبة
  .\auto-build.ps1 -ProjectDir C:\Projects\site -DescriptionFile .\brief.md -Monitor

.EXAMPLE
  # بناء مع فحص جودة الواجهات
  .\auto-build.ps1 -Description "متجر إلكتروني" -Monitor -RunChecklist

.EXAMPLE
  # بناء كامل + فحص جودة + تجهيز للصيانة التلقائية
  .\auto-build.ps1 -Description "تطبيق ويب" -Monitor -RunChecklist -LoopReady
#>

param(
  [string]$ProjectDir = (Get-Location).Path,
  [string]$Description = "",
  [string]$DescriptionFile = "",
  [string]$PlanFile = "PLAN.md",
  [string]$LogFile = "auto-build-log.txt",
  [string]$ProgressFile = "progress.md",
  [int]$MaxSteps = 20,
  # 45 دقيقة افتراضاً لا 8 ساعات: وكيل غير مراقب على جهاز المستخدم يجب أن
  # يتوقف قبل أن يستهلك ليلة كاملة. ارفعها صراحةً عند الحاجة.
  [int]$TimeoutMinutes = 45,
  [switch]$Monitor,
  [switch]$RunChecklist,
  [switch]$LoopReady
)

# ─── الإعدادات ───
$ErrorActionPreference = "Continue"
$StartTime = Get-Date
$BuildId = "build-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$ScriptDir = $PSScriptRoot
$Global:ChildPid = $null

# تنظيف ملفات البرومبت المؤقتة القديمة (أقدم من ساعة) من جلسات سابقة
Get-ChildItem ([System.IO.Path]::GetTempPath()) -Filter "auto-build-prompt-*.txt" -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-1) } |
  Remove-Item -Force -ErrorAction SilentlyContinue

function Write-Step {
  param([string]$Message)
  $time = Get-Date -Format "HH:mm:ss"
  Write-Host "[$time] $Message" -ForegroundColor Cyan
}

function Write-Success {
  param([string]$Message)
  $time = Get-Date -Format "HH:mm:ss"
  Write-Host "[$time] ✅ $Message" -ForegroundColor Green
}

function Write-Warning {
  param([string]$Message)
  $time = Get-Date -Format "HH:mm:ss"
  Write-Host "[$time] ⚠️ $Message" -ForegroundColor Yellow
}

function Write-Error {
  param([string]$Message)
  $time = Get-Date -Format "HH:mm:ss"
  Write-Host "[$time] ❌ $Message" -ForegroundColor Red
}

# يمرّر برومبت متعدد الأسطر إلى claude عبر stdin بدل سطر الأوامر
# (Start-Process -ArgumentList لا يقتبس الوسائط ذات المسافات/الأسطر فيكسر النص)
function Start-ClaudePrint {
  param(
    [string]$Prompt,
    [string]$OutputLog,
    [string]$ErrorLog,
    [string]$WorkingDir
  )
  $promptFile = Join-Path ([System.IO.Path]::GetTempPath()) ("auto-build-prompt-" + [Guid]::NewGuid().ToString("N") + ".txt")
  Set-Content -Path $promptFile -Value $Prompt -Encoding UTF8
  $proc = Start-Process -NoNewWindow -FilePath "claude" `
    -ArgumentList "-p" `
    -WorkingDirectory $WorkingDir `
    -RedirectStandardInput $promptFile `
    -RedirectStandardOutput $OutputLog `
    -RedirectStandardError $ErrorLog `
    -PassThru
  return $proc
}

# ─── ١. التحقق من المتطلبات ───
Write-Step "🔍 التحقق من المتطلبات..."

# تحقق من وجود Claude Code
$claudePath = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claudePath) {
  Write-Error "Claude Code غير موجود في PATH. تأكد من تثبيته."
  exit 1
}
Write-Success "Claude Code موجود: $claudePath"

# تحقق من وجود Git
$gitPath = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $gitPath) {
  Write-Warning "Git غير موجود في PATH. سيشتغل بدون تحكم إصدارات."
}

# تحقق من المجلد
if (-not (Test-Path $ProjectDir)) {
  Write-Error "المجلد $ProjectDir غير موجود."
  exit 1
}
Set-Location $ProjectDir
Write-Success "المشروع: $ProjectDir"

# ─── ٢. قراءة وصف المشروع ───
Write-Step "📝 قراءة وصف المشروع..."

if ($DescriptionFile -and (Test-Path $DescriptionFile)) {
  $Description = Get-Content $DescriptionFile -Raw -Encoding UTF8
  Write-Success "تم قراءة الوصف من الملف: $DescriptionFile"
}
elseif (-not $Description) {
  Write-Error "ما كتبت وصف المشروع. استعمل -Description أو -DescriptionFile"
  exit 1
}
Write-Success "وصف المشروع: $($Description.Substring(0, [Math]::Min(100, $Description.Length)))..."

# ─── ٣. إنشاء PLAN.md ───
Write-Step "📋 إنشاء خطة المشروع ($PlanFile)..."

$planPrompt = @"
المهمة: أنشئ خطة مشروع تفصيلية جدًا بناءً على الوصف التالي.
لا تسألني أي سؤال. فقط اكتب الخطة.

وصف المشروع:
$Description

متطلبات الخطة:
- اكتب الخطة في ملف PLAN.md في المجلد الحالي
- قصمها لخطوات واضحة (step-by-step)
- كل خطوة: وش تسوي بالضبط، وين الملفات، وش تكتب
- أقصى عدد خطوات: $MaxSteps
- بعد كل خطوة، حدث progress.md (سجل وش صار)
- أول خطوة: تحضير البيئة (مجلدات، شجرة المشروع)
- آخر خطوة: اختبار أن كل شيء شغال
- حدد لكل خطوة وش يعتبر "اكتمال"
- لا تستخدم مكتبات خارجية ما هي مثبتة

اللغة: العربية
"@

try {
  $planLogPath = Join-Path $ProjectDir "plan-generation-log.txt"
  $planErrPath = Join-Path $ProjectDir "plan-generation-errors.txt"

  $planProc = Start-ClaudePrint -Prompt $planPrompt -OutputLog $planLogPath -ErrorLog $planErrPath -WorkingDir $ProjectDir
  Write-Step "جاري توليد الخطة (PID: $($planProc.Id))... (أنتظر)"

  # انتظر حتى يكتمل أو ٣ دقائق
  Start-Sleep -Seconds 30
  $waitCount = 0
  while ($waitCount -lt 6) {
    Start-Sleep -Seconds 30
    $waitCount++
    if (Test-Path $PlanFile) {
      $content = Get-Content $PlanFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
      if ($content -and $content.Length -gt 100) {
        Write-Success "تم إنشاء $PlanFile"
        break
      }
    }
    if ($waitCount -ge 6) {
      Write-Warning "الخطة ما اكتملت خلال ٣ دقائق. رح أكمل باللي موجود."
    }
  }
}
catch {
  Write-Warning "ما قدرت أولد الخطة تلقائيًا. بستخدم خطة يدوي."
}

# إذا ما انشأت خطة → أنشئ خطة افتراضية
if (-not (Test-Path $PlanFile) -or (Get-Item $PlanFile).Length -lt 50) {
  Write-Warning "إنشاء خطة افتراضية..."

  $defaultPlan = @"
# خطة المشروع

## الوصف
$Description

## البيئة
- نظام: Windows 11
- الأدوات: Node.js, Git, Claude Code

## الخطوات

### 1. إعداد البيئة
- أنشئ شجرة المجلدات الأساسية
- حضر package.json أو ملفات الإعداد
- **اكتمال:** مجلدات جاهزة + dependencies مثبتة

### 2. الهيكل الأساسي
- أنشئ الملفات الرئيسية
- حضر المسارات (routing)
- **اكتمال:** كل الملفات الهيكلية موجودة

### 3. المكونات والصفحات
- نفذ الصفحات حسب الوصف
- أضف المكونات المطلوبة
- **اكتمال:** كل الصفحات تعرض محتوى

### 4. ربط البيانات
- أضف API / Database
- اربط الواجهة بالبيانات
- **اكتمال:** البيانات تظهر في الصفحات

### 5. اختبار وتحسين
- اختبر كل صفحة
- صحح الأخطاء
- **اكتمال:** كل شيء شغال

## التعليمات
- نفذ الخطوات بالترتيب
- بعد كل خطوة، سجل في progress.md
- لا تسأل المستخدم أي سؤال
"@
  Set-Content -Path $PlanFile -Value $defaultPlan -Encoding UTF8
  Write-Success "تم إنشاء خطة افتراضية"
}
else {
  Write-Success "الخطة موجودة وجاهزة"
}

# ─── ٤. إنشاء progress.md ───
$progressInit = @"
# progress.md

**المشروع:** $(Split-Path $ProjectDir -Leaf)
**معرّف البناء:** $BuildId
**تاريخ البداية:** $(Get-Date -Format "yyyy-MM-dd HH:mm")
**الحالة:** ⏳ قيد التنفيذ
**آخر تحديث:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## الخطوات

| # | الحالة | الوصف |
|---|--------|-------|
"@
Set-Content -Path (Join-Path $ProjectDir $ProgressFile) -Value $progressInit -Encoding UTF8
Write-Success "تم إنشاء $ProgressFile"

# ─── ٥. تشغيل البناء في الخلفية ───
Write-Step "🚀 تشغيل البناء في الخلفية..."

# بناء التعليمات الإضافية
$extraInstructions = ""

if ($RunChecklist) {
  $extraInstructions += @"

قواعد جودة الواجهات (checklist-ui):
- بعد بناء كل صفحة أو مكون واجهة، طبق فحص /checklist-ui عليها
- افحص: الألوان (custom properties فقط، تباين ≥ 4.5:1)، الطوبوغرافيا (عناوين roman، بدون أزرار بسطرين)، التخطيط (لا horizontal scroll، 4 شاشات)، التفاعل (focus ring، 8 حالات)، المحظورات (لا أرقام مزيفة، لا كروم مزيف)
- إذا فشل أي بند، أصلحه فورًا ولا تنتقل للخطوة التالية
- سجل نتيجة الفحص في $ProgressFile تحت قسم "جودة الواجهة"
- إذا تجاوزت بندًا لأنه لا ينطبق، اشرح لماذا في سطر واحد
"@
}

if ($LoopReady) {
  $extraInstructions += @"

تجهيز Loop Engineering (بعد آخر خطوة):
- أنشئ مجلد .loop/ في جذر المشروع
- أنشئ ملف .loop/config.yaml بالأنماط الأساسية: daily-triage (L1) و dependency-sweeper (L1 patch-only)
- أضف ملف .loop/gate.yaml بسيط: allowlist للمجلدات (src/, lib/, components/) و denylist للمجلدات الحساسة (.env, node_modules, .git)
- اكتب في $ProgressFile قسم "جاهزية Loop Engineering" مع النتيجة
- اكتب: "لتفعيل المراقبة: شغّل npx @cobusgreyling/loop-init --from-config .loop/config.yaml"
"@
}

$buildPrompt = @"
اقرأ الملف $PlanFile في المجلد الحالي $(Get-Location).

نفذ كل الخطوات في الخطة بالترتيب. لا تخط أي خطوة.

قواعد صارمة:
- لا تسألني أي سؤال نهائيًا
- لا تفترض أن أي صلاحية ممنوحة. إن مُنع أمر، سجّل السبب في progress.md واكتب BLOCKED بدل الالتفاف عليه
- إذا صار خطأ، سجله في $ProgressFile وحاول تكمل
- إذا ما عرفت تكمل، اكتب BLOCKED: [السبب] في $ProgressFile وتوقف
- بعد كل خطوة كاملة، حدث $ProgressFile بخلاصة
- في $ProgressFile، اكتب لكل خطوة: تم / فشل / قيد التنفيذ / ملخص
- إذا خلصت كل الخطوات، اكتب DONE في $ProgressFile
- كل 3 خطوات، خلّص ملخص عام في $ProgressFile
$extraInstructions
الحد الأقصى $MaxSteps خطوة. لا تسوي أكتر من كذا.

ابدأ الآن.
"@

$logPath = Join-Path $ProjectDir $LogFile
$errorLogPath = Join-Path $ProjectDir (($LogFile -replace '\.txt$', '') + "-errors.txt")

$proc = Start-ClaudePrint -Prompt $buildPrompt -OutputLog $logPath -ErrorLog $errorLogPath -WorkingDir $ProjectDir
$Global:ChildPid = $proc.Id
Write-Success "✅ البناء شغال (PID: $Global:ChildPid)"

# ─── ٦. معلومات للمستخدم ───
Write-Host ""
Write-Host "════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  🤖 بناء المشروع شغال في الخلفية" -ForegroundColor Green
Write-Host "════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""
Write-Host "  📁 المشروع:     $ProjectDir" -ForegroundColor White
Write-Host "  🆔 البناء:      $BuildId" -ForegroundColor White
Write-Host "  🧵 PID:         $($Global:ChildPid)" -ForegroundColor White
Write-Host "  📝 سجل:         $LogFile" -ForegroundColor White
Write-Host "  📊 التقدم:       $ProgressFile" -ForegroundColor White
Write-Host "  ⏰ وقت البدء:   $($StartTime.ToString('HH:mm:ss'))" -ForegroundColor White
Write-Host "  ⏳ المهلة:      $TimeoutMinutes دقيقة" -ForegroundColor White
Write-Host ""
Write-Host "  أوامر المراقبة:" -ForegroundColor Yellow
Write-Host "  Get-Content $LogFile -Tail 20          ← آخر 20 سطر" -ForegroundColor Cyan
Write-Host "  Get-Content $ProgressFile               ← التقدم الحالي" -ForegroundColor Cyan
Write-Host "  Stop-Process -Id $($Global:ChildPid) ← إيقاف البناء" -ForegroundColor Cyan
Write-Host ""

# ─── ٧. مراقبة اختيارية ───
if ($Monitor) {
  Write-Step "👁️ تشغيل المراقبة..."
  Write-Warning "اضغط Ctrl+C لإيقاف المراقبة (البناء يظل شغال)"
  Write-Host ""

  $checkInterval = 60  # ثانية
  $elapsedMinutes = 0
  $lastProgressLength = 0

  while ($true) {
    Start-Sleep -Seconds $checkInterval
    $elapsedMinutes += 1

    # تحقق من سجل التقدم
    if (Test-Path $ProgressFile) {
      $progress = Get-Content $ProgressFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
      if ($progress -and $progress.Length -ne $lastProgressLength) {
        $lastProgressLength = $progress.Length
        Write-Host ""
        Write-Step "📊 تحديث التقدم (بعد $elapsedMinutes دقيقة):"

        # استخرج الخطوط اللي فيها "تم" أو "فشل" أو "BLOCKED" أو "DONE"
        $lines = $progress -split "`n" | Where-Object {
          $_ -match "(تم|فشل|BLOCKED|DONE|قيد|ملخص)"
        }
        foreach ($line in $lines) {
          Write-Host "  $line" -ForegroundColor White
        }

        # تحقق من اكتمال
        if ($progress -match "DONE") {
          Write-Host ""
          Write-Success "🎉 البناء اكتمل!"
          Write-Host "  افتح $LogFile للتفاصيل الكاملة"
          return
        }
        if ($progress -match "BLOCKED") {
          Write-Host ""
          Write-Error "⛔ البناء توقف! راجع $ProgressFile"
          return
        }
      }
    }

    # حدّ الخطوات — ملزم لا إرشادي. progress.md يسجّل سطراً لكل خطوة منجزة،
    # فنعدّها ونوقف العملية عند التجاوز بدل الاكتفاء بذكر الحد في البرومبت.
    if (Test-Path $ProgressFile) {
      $raw = Get-Content $ProgressFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
      if ($raw) {
        $stepCount = ([regex]::Matches($raw, '(?m)^\s*(?:[-*]\s*)?(?:\[[xX ]\]|الخطوة|Step)\s')).Count
        if ($stepCount -gt $MaxSteps) {
          Write-Warning "🚧 تجاوز حدّ الخطوات ($stepCount > $MaxSteps) — إيقاف البناء"
          try {
            Stop-Process -Id $Global:ChildPid -Force -ErrorAction Stop
            Write-Warning "  تم إيقاف العملية $($Global:ChildPid)"
          } catch {
            Write-Warning "  ما قدرت أوقف العملية $($Global:ChildPid) (يمكن خلصت)"
          }
          return
        }
      }
    }

    # تحقق من انتهاء المهلة
    $elapsed = (Get-Date) - $StartTime
    if ($elapsed.TotalMinutes -gt $TimeoutMinutes) {
      Write-Warning "⏰ المهلة انتهت ($TimeoutMinutes دقيقة) — إيقاف البناء"
      try {
        Stop-Process -Id $Global:ChildPid -Force -ErrorAction Stop
        Write-Warning "  تم إيقاف العملية $($Global:ChildPid)"
      }
      catch {
        Write-Warning "  ما قدرت أوقف العملية $($Global:ChildPid) (يمكن خلصت)"
      }
      return
    }

    # تحقق من أن العملية لسه حية
    $processAlive = Get-Process -Id $Global:ChildPid -ErrorAction SilentlyContinue
    if (-not $processAlive) {
      Write-Host ""
      Write-Success "⚙️ عملية البناء انتهت! راجع $LogFile"
      return
    }

    Write-Host "." -NoNewline -ForegroundColor DarkGray
  }
}

# ─── ٨. تذكير نهائي ───
Write-Host ""
Write-Host "  💡 ارجع لاحقًا واكتب:" -ForegroundColor Yellow
Write-Host "     Get-Content $LogFile -Tail 50" -ForegroundColor Cyan
Write-Host "     Get-Content $ProgressFile" -ForegroundColor Cyan
Write-Host ""
