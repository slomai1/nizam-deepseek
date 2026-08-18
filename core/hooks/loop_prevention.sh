#!/usr/bin/env bash
# loop_prevention.sh — PostToolUse (Bash)
# يعد الأخطاء ويمنع التكرار الأبدي

set -euo pipefail

COUNTER_FILE="$HOME/.claude/hooks/.error_count"
MAX_ERRORS=10

INPUT=$(cat)

# استخراج stderr من مخرجات الأداة
STDERR=$(echo "$INPUT" | grep -o '"stderr"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"stderr"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)

# إذا ما فيه stderr — أعِد العداد للصفر واخرج
if [ -z "$STDERR" ] || [ "$STDERR" = "" ]; then
  echo "0" > "$COUNTER_FILE"
  exit 0
fi

# فيه خطأ — زِد العداد
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE")
else
  COUNT=0
fi

COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if [ "$COUNT" -ge "$MAX_ERRORS" ]; then
  echo "⛔ ${COUNT} أخطاء متتالية — تم إيقاف التنفيذ" >&2
  echo "   الأخطاء المتكررة تشير إلى حلقة لا نهائية. راجع نهجك واسأل المستخدم." >&2
  echo "0" > "$COUNTER_FILE"
  exit 2
fi

# تحذير مبكر
if [ "$COUNT" -ge 5 ]; then
  echo "⚠️  ${COUNT} أخطاء متتالية — تقترب من الحد (${MAX_ERRORS})" >&2
fi

exit 0
