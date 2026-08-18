#!/usr/bin/env bash
# ============================================================
# بوابة فحص ما قبل النشر — يمنع تسريب أسرار أو بيانات شخصية
# الاستخدام: ./tools/pre-publish-check.sh [مسار-المستودع]
# الخروج: 0 = نظيف، 1 = وجد مخالفات
# ============================================================
set -uo pipefail

REPO_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$REPO_DIR"

FAILED=0
# نمط يتجاهل ملفات السكربتات التي تحتوي أنماط كشف أسرار (مثل block_secrets.sh)
IGNORE_PATHS="block_secrets.sh|pre-publish-check.sh|03-الأخطاء-الشائعة.md"

red()  { printf "\033[0;31m%s\033[0m\n" "$1"; }
green(){ printf "\033[0;32m%s\033[0m\n" "$1"; }

check() {
  local label="$1" pattern="$2"
  local hits
  hits=$(grep -rInE --exclude-dir=.git "$pattern" . 2>/dev/null | grep -vE "$IGNORE_PATHS" || true)
  if [ -n "$hits" ]; then
    red "✗ $label — وجد تطابقات:"
    echo "$hits" | head -10
    FAILED=1
  else
    green "✓ $label"
  fi
}

echo "فحص ما قبل النشر — $REPO_DIR"
echo "========================================"

# ١. أسرار حقيقية
check "توكنات Anthropic/OpenAI"          'sk-(ant-)?[a-zA-Z0-9]{20,}'
check "توكنات GitHub"                    'ghp_[a-zA-Z0-9]{36}'
check "توكنات Vercel OAuth"              'vca_[a-zA-Z0-9]|vcr_[a-zA-Z0-9]'
check "توكنات Supabase OAuth"            'sbp_[a-zA-Z0-9]|sba_[a-zA-Z0-9]'
check "رؤوس Bearer"                      'Bearer [a-zA-Z0-9._-]{20,}'

# ٢. بيانات شخصية
check "بريد مشروع عميل"                  'deploy@rakb\.app'
check "اسم مستخدم في مسارات مطلقة"       'C:/Users/sloma|C:\\Users\\sloma|C--Users-sloma'

# ٣. ملفات محظورة (لا يجب أن تكون في المستودع إطلاقاً)
for f in .credentials.json .auth.sec .mcp.json settings.local.json history.jsonl; do
  if [ -e "$f" ]; then
    red "✗ ملف محظور موجود: $f"
    FAILED=1
  else
    green "✓ لا يوجد $f"
  fi
done

echo "========================================"
if [ "$FAILED" = "0" ]; then
  green "✓ نظيف — جاهز للنشر"
  exit 0
else
  red "✗ وجد مخالفات — لا تنشر قبل معالجتها"
  exit 1
fi
