#!/usr/bin/env bash
# ============================================================
# نظام DeepSeek × Claude Code — سكربت التركيب (bash)
# macOS / Linux / Windows (عبر Git Bash أو WSL)
#
# الاستخدام:
#   ./install.sh            # تركيب كامل
#   ./install.sh --dry-run  # عرض الخطوات دون تنفيذ
#   ./install.sh --no-backup  # بلا نسخة احتياطية (حذار)
# ============================================================

set -euo pipefail

DRY_RUN=0
DO_BACKUP=1
SKIP_CLAUDE_CHECK=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-backup) DO_BACKUP=0 ;;
    # للاختبار الآلي (CI) حيث لا يكون Claude Code مثبّتاً
    --skip-claude-check) SKIP_CLAUDE_CHECK=1 ;;
  esac
done

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CORE_DIR="$REPO_DIR/core"
TPL_DIR="$REPO_DIR/templates"

# ألوان
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}⚠ ${NC} %s\n" "$1"; }
fail() { printf "${RED}✗${NC} %s\n" "$1"; }
step() { printf "\n${YELLOW}▶ ${NC}%s\n" "$1"; }

dry() {
  if [ "$DRY_RUN" = "1" ]; then
    printf "  (سيتنفذ) %s\n" "$*"
    return 0
  fi
  "$@"
}

echo "==============================================="
echo "  نظام DeepSeek × Claude Code — التركيب"
echo "==============================================="
[ "$DRY_RUN" = "1" ] && warn "وضع المعاينة: لن يُنفذ أي تعديل"

# ------------------------------------------------------------
# ١. فحص المتطلبات
# ------------------------------------------------------------
step "١. فحص المتطلبات"

if command -v claude >/dev/null 2>&1; then
  ok "Claude Code موجود"
elif [ "$SKIP_CLAUDE_CHECK" = "1" ]; then
  warn "تخطّي فحص Claude Code (--skip-claude-check)"
else
  fail "Claude Code غير موجود في PATH — ثبّته أولاً: npm i -g @anthropic-ai/claude-code"
  exit 1
fi

if command -v node >/dev/null 2>&1; then
  # node:sqlite أُضيف في Node 22.5 — نفحص الوحدة فعلياً لا رقم الإصدار
  if node -e "require('node:sqlite')" 2>/dev/null; then
    ok "Node موجود (v$(node -v)) — مع دعم node:sqlite"
  else
    fail "Node ≥ 22.5 مطلوب ليعمل node:sqlite — لديك v$(node -v)"
    exit 1
  fi
else
  fail "Node غير موجود — مطلوب ≥ 22.5"
  exit 1
fi

if command -v bash >/dev/null 2>&1; then
  ok "bash موجود"
else
  fail "bash غير موجود — الـ hooks كلها bash"
  exit 1
fi

# ------------------------------------------------------------
# ٢. نسخة احتياطية
# ------------------------------------------------------------
BACKUP_DIR="$HOME/.claude.backup-$(date +%Y%m%d-%H%M%S)"
if [ -d "$CLAUDE_DIR" ] && [ "$DO_BACKUP" = "1" ]; then
  step "٢. نسخة احتياطية"
  if [ "$DRY_RUN" = "1" ]; then
    dry cp -r "$CLAUDE_DIR" "$BACKUP_DIR"
  else
    cp -r "$CLAUDE_DIR" "$BACKUP_DIR"
    ok "نُسخت ~/.claude → $BACKUP_DIR"
  fi
else
  warn "تخطّي النسخة الاحتياطية (لا مجلد موجود أو --no-backup)"
fi

# ------------------------------------------------------------
# ٣. نسخ core إلى ~/.claude (دمج، لا حذف)
# ------------------------------------------------------------
step "٣. نسخ مكوّنات النظام"
mkdir -p "$CLAUDE_DIR"
for sub in rules hooks commands workflows skills scripts; do
  [ -d "$CORE_DIR/$sub" ] || continue
  if [ "$DRY_RUN" = "1" ]; then
    dry cp -r "$CORE_DIR/$sub/." "$CLAUDE_DIR/$sub/"
  else
    mkdir -p "$CLAUDE_DIR/$sub"
    cp -r "$CORE_DIR/$sub/." "$CLAUDE_DIR/$sub/"
  fi
done
if [ "$DRY_RUN" = "1" ]; then
  dry cp "$CORE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
else
  cp "$CORE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
fi
ok "نُسخ core/ → ~/.claude (دمج)"

# على يونكس: اجعل الـ hooks قابلة للتنفيذ (نتجاوز Git Bash على Windows)
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) : ;;
  *) chmod +x "$CLAUDE_DIR"/hooks/*.sh 2>/dev/null || true ;;
esac

# ------------------------------------------------------------
# ٤. توليد/دمج settings.json
# ------------------------------------------------------------
step "٤. إعداد settings.json"
DEFAULT_SHELL="bash"
if [ -n "${OSTYPE:-}" ] && [[ "$OSTYPE" == msys* || "$OSTYPE" == win32* ]]; then
  DEFAULT_SHELL="powershell"
fi

MERGE_ARGS=(--template "$TPL_DIR/settings.template.json" --target "$CLAUDE_DIR/settings.json" --shell "$DEFAULT_SHELL")
if [ "$DRY_RUN" = "1" ]; then MERGE_ARGS+=(--dry-run); fi
node "$REPO_DIR/install/merge-settings.js" "${MERGE_ARGS[@]}"
ok "settings.json جاهز (defaultShell: $DEFAULT_SHELL)"

# ------------------------------------------------------------
# ٥. تهيئة الذاكرة
# ------------------------------------------------------------
step "٥. تهيئة الذاكرة"
if [ -f "$CLAUDE_DIR/data/deepseek.db" ]; then
  warn "قاعدة ذاكرة موجودة — لا نعيد إنشاءها"
  # ترحيل التفرّد المركّب إن كانت القاعدة على المخطط القديم (يتخطى نفسه إن تم)
  if [ "$DRY_RUN" = "1" ]; then
    dry node "$REPO_DIR/install/migrate-memory-scope.js" --db "$CLAUDE_DIR/data/deepseek.db" --dry-run
  else
    # فشل الترحيل يوقف التركيب: قاعدة على المخطط القديم مع مزامنة جديدة
    # تعني فشلاً صامتاً عند أول اسم متكرر بين مشروعين
    if ! node "$REPO_DIR/install/migrate-memory-scope.js" --db "$CLAUDE_DIR/data/deepseek.db"; then
      fail "فشل ترحيل قاعدة الذاكرة — التركيب متوقف"
      echo "  القاعدة لم تتغيّر. عالج السبب أعلاه ثم أعد التشغيل." >&2
      echo "  نسختك الاحتياطية: ${BACKUP_DIR:-(لم تُنشأ — استخدمت --no-backup)}" >&2
      exit 1
    fi
  fi
else
  if [ "$DRY_RUN" = "1" ]; then
    dry node "$REPO_DIR/install/init-memory.js" --claude-dir "$CLAUDE_DIR"
  else
    node "$REPO_DIR/install/init-memory.js" --claude-dir "$CLAUDE_DIR"
    ok "قاعدة الذاكرة أُنشئت من schema.sql"
  fi
fi

# ------------------------------------------------------------
# ٦. مفتاح DeepSeek
# ------------------------------------------------------------
step "٦. مفتاح DeepSeek"
if [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
  ok "ANTHROPIC_AUTH_TOKEN موجود في البيئة — لن نكتبه في أي ملف"
else
  warn "لم نجد ANTHROPIC_AUTH_TOKEN في البيئة."
  echo "  عيّنه قبل تشغيل Claude Code:"
  echo "    export ANTHROPIC_AUTH_TOKEN=\"sk-...\""
  echo "  (أضفه إلى ~/.bashrc أو ~/.zshrc ليستمر)"
fi

# ------------------------------------------------------------
# ٧. فحص نهائي
# ------------------------------------------------------------
step "٧. الفحص النهائي"
ok "المكوّنات المنقولة: rules/hooks/commands/workflows/skills/scripts"
ok "الملحقات (١٨) ستُجلب تلقائياً عند أول تشغيل لـ Claude Code"
[ "$DRY_RUN" = "1" ] && { warn "وضع المعاينة — لم يُنفذ أي تعديل فعلي"; exit 0; }
echo ""
echo "==============================================="
echo "  اكتمل التركيب. شغّل: claude"
echo "  ثم جرّب: /model opus ثم /model sonnet"
echo "==============================================="
