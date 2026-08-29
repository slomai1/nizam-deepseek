#!/usr/bin/env bash
# ============================================================
# تثبيت المتطلبات المسبقة لنظام DeepSeek × Claude Code
# macOS (أساسي) / Linux (أغلب الحالات) — وملاحظات Git Bash على Windows
#
# يثبّت: git · Homebrew (macOS) · Node ≥ 22.5 (لأجل node:sqlite)
#        · Claude Code (عبر npm عالمياً)
#
# الاستخدام:
#   ./install-prereq.sh            # يتخطّى ما هو موجود
#   ./install-prereq.sh --check    # فحص فقط بلا تثبيت
#   ./install-prereq.sh --claude-only   # ثبّت Claude Code فقط
#
# بعد النجاح، شغّل install.sh ثم عيّن مفتاحك.
# ============================================================

set -euo pipefail

CHECK_ONLY=0
CLAUDE_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    --claude-only) CLAUDE_ONLY=1 ;;
  esac
done

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}⚠ ${NC} %s\n" "$1"; }
fail() { printf "${RED}✗${NC} %s\n" "$1"; }
step() { printf "\n${YELLOW}▶ ${NC}%s\n" "$1"; }

os() { uname -s; }

echo "==============================================="
echo "  تثبيت متطلبات نظام DeepSeek × Claude Code"
echo "==============================================="
[ "$CHECK_ONLY" = "1" ] && warn "وضع الفحص فقط — لن يُثبَّت شيء"

# ------------------------------------------------------------
# ١. git
# ------------------------------------------------------------
step "١. git"
if command -v git >/dev/null 2>&1; then
  ok "git موجود (v$(git --version | cut -d' ' -f3))"
elif [ "$CHECK_ONLY" = "0" ]; then
  warn "git مفقود — أثبّته."
  if [ "$(os)" = "Darwin" ]; then
    # أدوات المطوّرين تثبّت git و clang وcurl معاً
    xcode-select --install || {
      echo "  تعذّر فتح مُثبّت Xcode CLI. بدِيل: Homebrew" >&2
      warn "ركّب Homebrew أولاً (الخطوة ٢) ثم: brew install git"
    }
  else
    echo "  على لينكس: sudo apt install git  (أو pacman/dnf بحسب التوزيعة)" >&2
  fi
else
  fail "git غير موجود"
fi

# ------------------------------------------------------------
# ٢. Homebrew (macOS فقط)
# ------------------------------------------------------------
if [ "$(os)" = "Darwin" ]; then
  step "٢. Homebrew"
  if command -v brew >/dev/null 2>&1; then
    ok "Homebrew موجود ($(brew --version | head -1))"
  elif [ "$CHECK_ONLY" = "0" ]; then
    warn "Homebrew مفقود — أُثبّته الآن."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # تفعيل brew في shell الحالي (أبّل سيليكون/إنتل)
    eval "$(/usr/bin/brew shellenv 2>/dev/null || /opt/homebrew/bin/brew shellenv 2>/dev/null || true)"
    ok "Homebrew جاهز"
  else
    fail "Homebrew مفقود"
  fi
fi

# ------------------------------------------------------------
# ٣. Node ≥ 22.5 (لأجل node:sqlite)
# ------------------------------------------------------------
step "٣. Node (يتطلّب ≥ 22.5 لدعم node:sqlite)"
NODE_OK=0
if command -v node >/dev/null 2>&1; then
  if node -e "require('node:sqlite')" 2>/dev/null; then
    NODE_OK=1
    ok "Node موجود (v$(node -v)) — مع دعم node:sqlite"
  else
    fail "Node موجود لكنه أقدم من 22.5 (v$(node -v)) — node:sqlite غير متاح"
  fi
else
  fail "node غير موجود"
fi

if [ "$NODE_OK" != "1" ] && [ "$CHECK_ONLY" = "0" ]; then
  if [ "$(os)" = "Darwin" ]; then
    warn "أُرقّي Node عبر Homebrew (يعطيك 22.5+)."
    brew install node || brew upgrade node
  else
    warn "على لينكس: استخدم nvm أو مدير حزمك."
  fi
fi

# ------------------------------------------------------------
# ٤. Claude Code (npm عالمي)
# ------------------------------------------------------------
if [ "$CLAUDE_ONLY" = "1" ]; then
  step "٤. Claude Code (فقط)"
elif [ "$CHECK_ONLY" = "1" ] || [ "$NODE_OK" = "1" ]; then
  step "٤. Claude Code"
fi

if command -v claude >/dev/null 2>&1; then
  ok "Claude Code موجود (v$(claude --version 2>/dev/null || echo '؟'))"
elif [ "$CHECK_ONLY" = "0" ]; then
  [ "$NODE_OK" = "1" ] || fail "node غير صالح — ثبّت node أولاً ثم أعد التشغيل"
  warn "أُثبّت Claude Code عبر npm (عالمياً)."
  npm install -g @anthropic-ai/claude-code
  ok "Claude Code جاهز — إعادة فتح الطرفية قد تطلّب إضافة npm bin إلى PATH"
else
  fail "Claude Code غير موجود — ثبّته: npm install -g @anthropic-ai/claude-code"
fi

# ------------------------------------------------------------
# فحص أخير
# ------------------------------------------------------------
echo ""
echo "══ الملخص ══"
command -v git  >/dev/null 2>&1 && ok "git"      || warn "git مفقود"
command -v node >/dev/null 2>&1 && ok "node"     || warn "node مفقود"
command -v claude >/dev/null 2>&1 && ok "claude" || warn "claude مفقود"

[ "$CHECK_ONLY" = "1" ] && { echo ""; exit 0; }
echo ""
echo "اكتمل تثبيت المتطلبات. الخطوة التالية:"
echo "  ./install.sh   # يركّب النظام ويولد settings.json"
echo "  ثم عيّن مفتاح DeepSeek:  export ANTHROPIC_AUTH_TOKEN=\"sk-...\""
