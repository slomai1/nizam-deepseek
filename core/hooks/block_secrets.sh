#!/usr/bin/env bash
# block_secrets.sh — PreToolUse (Bash)
# يكشف API keys في الأوامر ويمنعها
# الاستخراج عبر node (JSON حقيقي) — يعالج الاقتباسات المهرّبة التي يكسرها grep

set -euo pipefail

INPUT=$(cat)

COMMAND=$(printf '%s' "$INPUT" | node -e '
let s = "";
process.stdin.on("data", (d) => (s += d));
process.stdin.on("end", () => {
  try {
    const j = JSON.parse(s);
    const ti = j.tool_input || {};
    const c = ti.command || j.command || "";
    process.stdout.write(String(c));
  } catch (e) {
    process.stdout.write("__PARSE_FAILED__");
  }
});
' 2>/dev/null || printf '__PARSE_FAILED__')

# fail-closed: تعذّر التحليل (أو غياب node) → نفحص المدخل الخام كاملاً
# بدل تمرير أمر قد يحمل مفتاحاً بلا فحص
if [ "$COMMAND" = "__PARSE_FAILED__" ] || [ -z "${COMMAND}" ]; then
  if [ "$COMMAND" = "__PARSE_FAILED__" ]; then
    COMMAND="$INPUT"
  else
    exit 0   # تحليل ناجح بلا أمر — لا شيء لفحصه
  fi
fi

# ─── أنماط المفاتيح والأسرار ───
SECRETS=(
  'sk-[a-zA-Z0-9]{16,}'           # Anthropic / OpenAI / DeepSeek keys (تغطية أوسع)
  'sk-ant-[a-zA-Z0-9_-]{20,}'     # Anthropic Admin keys
  'AIza[0-9A-Za-z_-]{35}'         # Google API keys
  'ghp_[a-zA-Z0-9]{36}'           # GitHub Personal Access Token (classic)
  'github_pat_[a-zA-Z0-9_]{20,}'  # GitHub Fine-grained token
  'xox[bpras]-[0-9]{10,}-[0-9]{10,}-[a-z0-9]{32}'  # Slack tokens
  'AKIA[0-9A-Z]{16}'              # AWS Access Key
  'eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}'  # JWT
  'PRIVATE[[:space:]]+KEY'
  '-----BEGIN[[:space:]]+(RSA|OPENSSH|EC|DSA)[[:space:]]+PRIVATE[[:space:]]+KEY'
  'supabase\.co/anonymous'
  'Bearer[[:space:]]+[a-zA-Z0-9_-]{20,}'
  'NEXT_PUBLIC_SUPABASE_ANON_KEY'
)

# تمريرة grep واحدة بكل الأنماط — تجنّباً لتكلفة استدعاء grep لكل نمط
JOINED=$(printf '%s|' "${SECRETS[@]}")
JOINED="${JOINED%|}"

if printf '%s' "$COMMAND" | grep -qE "$JOINED"; then
  for pattern in "${SECRETS[@]}"; do
    if printf '%s' "$COMMAND" | grep -qE "$pattern"; then
      echo "🔒 مفتاح سري مكشوف في الأمر — ممنوع!" >&2
      echo "   النمط: $pattern" >&2
      echo "   استخدم متغير بيئة بدل النص الصريح." >&2
      exit 2
    fi
  done
  echo "🔒 مفتاح سري مكشوف في الأمر — ممنوع!" >&2
  exit 2
fi

exit 0
