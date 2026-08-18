#!/usr/bin/env bash
# loop_prevention.sh — PostToolUse (Bash)
# يعدّ الأخطاء الجادة المتتالية ويمنع التكرار الأبدي
# لا يعدّ كل stderr — git/npm تكتب تحذيرات stderr حتى عند النجاح

set -euo pipefail

COUNTER_FILE="$HOME/.claude/hooks/.error_count"
MAX_ERRORS=10

INPUT=$(cat)

# استخراج stderr عبر node (JSON حقيقي)
STDERR=$(printf '%s' "$INPUT" | node -e '
let s = "";
process.stdin.on("data", (d) => (s += d));
process.stdin.on("end", () => {
  try {
    const j = JSON.parse(s);
    const e = (j.tool_response && j.tool_response.stderr) || j.stderr || "";
    process.stdout.write(String(e));
  } catch (err) {
    process.stdout.write("");
  }
});
')

# أنماط الخطأ الجادة فقط — تحذيرات git/npm لا تُحتسب
if ! printf '%s' "$STDERR" | grep -qE '(error|fatal|traceback|command failed|not found|no such file|permission denied|EACCES|ENOENT|Segmentation fault|Killed)'; then
  echo "0" > "$COUNTER_FILE"
  exit 0
fi

# خطأ جاد — زِد العداد
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
