#!/usr/bin/env bash
# block_secrets.sh — PreToolUse (Bash)
# يكشف API keys في الأوامر ويمنعها

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"//;s/"$//')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# ─── أنماط المفاتيح والأسرار ───
SECRETS=(
  'sk-[a-zA-Z0-9]{20,}'           # Anthropic / OpenAI keys
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

for pattern in "${SECRETS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "🔒 مفتاح سري مكشوف في الأمر — ممنوع!" >&2
    echo "   النمط: $pattern" >&2
    echo "   الأمر يحتوي على مفتاح API أو سر. استخدم متغير بيئة بدل النص الصريح." >&2
    exit 2
  fi
done

exit 0
