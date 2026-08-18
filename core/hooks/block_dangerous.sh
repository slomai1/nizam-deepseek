#!/usr/bin/env bash
# block_dangerous.sh — PreToolUse (Bash)
# يمنع 20+ أمر خطير قبل التنفيذ

set -euo pipefail

# قراءة JSON المدخل من stdin
INPUT=$(cat)

# استخراج الأمر من JSON
COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"//;s/"$//')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# ─── قائمة الأوامر الخطيرة ───
DANGEROUS=(
  'rm[[:space:]]+-rf[[:space:]]+/'
  'rm[[:space:]]+-rf[[:space:]]+~'
  'rm[[:space:]]+-rf[[:space:]]+\$HOME'
  'rm[[:space:]]+-rf[[:space:]]+\.\./\.\.[[:space:]]'
  'git[[:space:]]+push[[:space:]]+--force[[:space:]]+origin[[:space:]]+main'
  'git[[:space:]]+push[[:space:]]+--force[[:space:]]+origin[[:space:]]+master'
  'git[[:space:]]+push[[:space:]]+-f[[:space:]]+origin[[:space:]]+main'
  'git[[:space:]]+push[[:space:]]+-f[[:space:]]+origin[[:space:]]+master'
  'DROP[[:space:]]+TABLE'
  'DROP[[:space:]]+DATABASE'
  'TRUNCATE[[:space:]]+TABLE'
  'chmod[[:space:]]+777'
  'chmod[[:space:]]+-R[[:space:]]+777'
  'chown[[:space:]]+-R[[:space:]]+root'
  'npm[[:space:]]+publish'
  'mkfs\.'
  'dd[[:space:]]+if='
  ':(){ :|:& };:'   # fork bomb
  '>\/dev\/sda'
  'format[[:space:]]+C:'
  'del[[:space:]]+\/f[[:space:]]+\/s[[:space:]]+\/q[[:space:]]+C:\\'
  # ─── git — حماية أوسع (مكمّلة من git-guardrails) ───
  'git[[:space:]]+push[[:space:]]+--force'
  'git[[:space:]]+push[[:space:]]+-f'
  'git[[:space:]]+reset[[:space:]]+--hard'
  'git[[:space:]]+clean[[:space:]]+-f'
  'git[[:space:]]+branch[[:space:]]+-D'
  'git[[:space:]]+checkout[[:space:]]+\.'
  'git[[:space:]]+restore[[:space:]]+\.'
)

for pattern in "${DANGEROUS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "❌ أمر خطير ممنوع: $COMMAND" >&2
    echo "   النمط المطابق: $pattern" >&2
    exit 2
  fi
done

exit 0
