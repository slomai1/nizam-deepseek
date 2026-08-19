# ============================================================
# نظام DeepSeek × Claude Code — سكربت التركيب (Windows PowerShell)
#
# الاستخدام:
#   .\install.ps1            # تركيب كامل
#   .\install.ps1 -DryRun    # عرض الخطوات دون تنفيذ
#   .\install.ps1 -NoBackup  # بلا نسخة احتياطية (حذار)
# ============================================================
param(
  [switch]$DryRun,
  [switch]$NoBackup
)

$ErrorActionPreference = "Stop"

$RepoDir = Split-Path $PSScriptRoot -Parent
$ClaudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME ".claude" }
$CoreDir = Join-Path $RepoDir "core"
$TplDir = Join-Path $RepoDir "templates"
$NodeExe = "node"

function Write-Step($msg) { Write-Host "`n▶ $msg" -ForegroundColor Yellow }
function Write-Ok($msg) { Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "✗ $msg" -ForegroundColor Red }

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  نظام DeepSeek × Claude Code — التركيب"
Write-Host "===============================================" -ForegroundColor Cyan
if ($DryRun) { Write-Warn "وضع المعاينة: لن يُنفذ أي تعديل" }

# ------------------------------------------------------------
# ١. فحص المتطلبات
# ------------------------------------------------------------
Write-Step "١. فحص المتطلبات"

if (Get-Command claude -ErrorAction SilentlyContinue) {
  Write-Ok "Claude Code موجود"
} else {
  Write-Fail "Claude Code غير موجود — ثبّته: npm i -g @anthropic-ai/claude-code"
  exit 1
}

if (Get-Command node -ErrorAction SilentlyContinue) {
  # node:sqlite أُضيف في Node 22.5 — نفحص الوحدة فعلياً لا رقم الإصدار
  node -e "require('node:sqlite')" 2>$null
  if ($LASTEXITCODE -eq 0) {
    Write-Ok "Node موجود (v$(node -v)) — مع دعم node:sqlite"
  } else {
    Write-Fail "Node ≥ 22.5 مطلوب ليعمل node:sqlite — لديك v$(node -v)"
    exit 1
  }
} else {
  Write-Fail "Node غير موجود — مطلوب ≥ 22.5"
  exit 1
}

# ------------------------------------------------------------
# ٢. نسخة احتياطية
# ------------------------------------------------------------
$BackupDir = Join-Path $HOME (".claude.backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
if ((Test-Path $ClaudeDir) -and -not $NoBackup) {
  Write-Step "٢. نسخة احتياطية"
  if ($DryRun) {
    Write-Warn "(سيتنفذ) نسخ $ClaudeDir → $BackupDir"
  } else {
    Copy-Item -Path $ClaudeDir -Destination $BackupDir -Recurse -Force
    Write-Ok "نُسخت $ClaudeDir → $BackupDir"
  }
} else {
  Write-Warn "تخطّي النسخة الاحتياطية (لا مجلد موجود أو -NoBackup)"
}

# ------------------------------------------------------------
# ٣. نسخ core إلى ~/.claude (دمج، لا حذف)
# ------------------------------------------------------------
Write-Step "٣. نسخ مكوّنات النظام"
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
foreach ($sub in @('rules','hooks','commands','workflows','skills','scripts')) {
  $srcSub = Join-Path $CoreDir $sub
  if (-not (Test-Path $srcSub)) { continue }
  if ($DryRun) {
    Write-Warn "(سيتنفذ) نسخ $srcSub → $ClaudeDir\$sub"
  } else {
    New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir $sub) | Out-Null
    Copy-Item -Path (Join-Path $srcSub '*') -Destination (Join-Path $ClaudeDir $sub) -Recurse -Force
  }
}
if ($DryRun) {
  Write-Warn "(سيتنفذ) نسخ CLAUDE.md"
} else {
  Copy-Item -Path (Join-Path $CoreDir 'CLAUDE.md') -Destination (Join-Path $ClaudeDir 'CLAUDE.md') -Force
}
Write-Ok "نُسخ core/ → ~/.claude (دمج)"

# ------------------------------------------------------------
# ٤. إعداد settings.json
# ------------------------------------------------------------
Write-Step "٤. إعداد settings.json"
$settingsArgs = @(
  '--template', (Join-Path $TplDir 'settings.template.json'),
  '--target', (Join-Path $ClaudeDir 'settings.json'),
  '--shell', 'powershell'
)
if ($DryRun) { $settingsArgs += '--dry-run' }
& $NodeExe (Join-Path $RepoDir 'install\merge-settings.js') @settingsArgs
if ($LASTEXITCODE -ne 0) { Write-Fail "فشل دمج settings.json"; exit 1 }
Write-Ok "settings.json جاهز (defaultShell: powershell)"

# ------------------------------------------------------------
# ٥. تهيئة الذاكرة
# ------------------------------------------------------------
Write-Step "٥. تهيئة الذاكرة"
$dbPath = Join-Path $ClaudeDir 'data\deepseek.db'
if (Test-Path $dbPath) {
  Write-Warn "قاعدة ذاكرة موجودة — لا نعيد إنشاءها"
  # ترحيل التفرّد المركّب إن كانت على المخطط القديم (يتخطى نفسه إن تم)
  if ($DryRun) {
    & $NodeExe (Join-Path $RepoDir 'install\migrate-memory-scope.js') --db $dbPath --dry-run
  } else {
    & $NodeExe (Join-Path $RepoDir 'install\migrate-memory-scope.js') --db $dbPath
    if ($LASTEXITCODE -ne 0) {
      Write-Fail "فشل ترحيل قاعدة الذاكرة — التركيب متوقف"
      Write-Host "  القاعدة لم تتغيّر. عالج السبب أعلاه ثم أعد التشغيل."
      exit 1
    }
  }
} else {
  if ($DryRun) {
    Write-Warn "(سيتنفذ) إنشاء قاعدة الذاكرة من schema.sql"
  } else {
    & $NodeExe (Join-Path $RepoDir 'install\init-memory.js') --claude-dir $ClaudeDir
    if ($LASTEXITCODE -ne 0) { Write-Fail "فشل تهيئة الذاكرة"; exit 1 }
    Write-Ok "قاعدة الذاكرة أُنشئت من schema.sql"
  }
}

# ------------------------------------------------------------
# ٦. مفتاح DeepSeek
# ------------------------------------------------------------
Write-Step "٦. مفتاح DeepSeek"
if ($env:ANTHROPIC_AUTH_TOKEN) {
  Write-Ok "ANTHROPIC_AUTH_TOKEN موجود في البيئة — لن نكتبه في أي ملف"
} else {
  Write-Warn "لم نجد ANTHROPIC_AUTH_TOKEN في البيئة."
  Write-Host "  عيّنه قبل تشغيل Claude Code:"
  Write-Host "    [Environment]::SetEnvironmentVariable('ANTHROPIC_AUTH_TOKEN','sk-...','User')"
  Write-Host "  أو من إعدادات النظام → متغيرات البيئة. (لا يُكتب في أي ملف داخل المستودع)"
}

# ------------------------------------------------------------
# ٧. فحص نهائي
# ------------------------------------------------------------
Write-Step "٧. الفحص النهائي"
Write-Ok "المكوّنات المنقولة: rules/hooks/commands/workflows/skills/scripts"
Write-Ok "الملحقات (١٨) ستُجلب تلقائياً عند أول تشغيل لـ Claude Code"
if ($DryRun) {
  Write-Warn "وضع المعاينة — لم يُنفذ أي تعديل فعلي"
  exit 0
}
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  اكتمل التركيب. شغّل: claude"
Write-Host "  ثم جرّب: /model opus ثم /model sonnet"
Write-Host "===============================================" -ForegroundColor Cyan
