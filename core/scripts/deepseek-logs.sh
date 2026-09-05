#!/usr/bin/env bash
# ============================================================
# deepseek-logs.sh — مناظر bash لـ deepseek-logs.ps1 (macOS / Linux / Git Bash)
# يراقب أنماط أخطاء البوابة/MCP في سجل الجلسات.
#
# الاستخدام: bash deepseek-logs.sh [عدد-الأسطر، الافتراضي 5000]
# يصنّف إشارات 429/403/401/timeout/اتصال في آخر N سطراً من history.jsonl
# ============================================================

set -uo pipefail

LINES="${1:-5000}"
HIST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/history.jsonl"

if [ ! -f "$HIST" ]; then
  printf '⚠️ history.jsonl غير موجود — لا بيانات جلسات: %s\n' "$HIST" >&2
  exit 1
fi

printf '=== فحص أنماط أخطاء البوابة/MCP في آخر %s سطراً ===\n' "$LINES"

# ملاحظة: نفحص النص المعروض في history.jsonl لا استجابات API الخام.
# الأرقام المجردة (مثل 429 وحدها) تعطي إيجابيات كاذبة من الطوابع الزمنية
# والكود، لذا نطابق عبارات الخطأ السياقية فقط.
declare -A PATTERNS=(
  ['rate limit']='rate[[:space:]]*limit|too many requests|429[[:space:]]*too[[:space:]]*many|hit the rate'
  ['auth error']='403[[:space:]]*forbidden|401[[:space:]]*unauthorized|permission denied|access denied'
  ['timeout/connection']='timed[[:space:]]*out|connection[[:space:]]*(timed|refused|closed)|ECONN|network error|offline'
  ['gateway/upstream']='bad gateway|502|504|upstream error|gateway error'
  ['MCP not connected']='not connected|mcp.*(failed|error)|extension is not connected'
)
ORDER=('rate limit' 'auth error' 'timeout/connection' 'gateway/upstream' 'MCP not connected')

declare -A COUNTS SAMPLES
for c in "${ORDER[@]}"; do COUNTS[$c]=0; done

while IFS= read -r line; do
  for c in "${ORDER[@]}"; do
    if printf '%s' "$line" | grep -qE "${PATTERNS[$c]}"; then
      COUNTS[$c]=$(( ${COUNTS[$c]} + 1 ))
      if [ -z "${SAMPLES[$c]:-}" ]; then
        SAMPLES[$c]="${line:0:120}"
      fi
    fi
  done
done < <(tail -n "$LINES" "$HIST")

TOTAL=0
for c in "${ORDER[@]}"; do TOTAL=$((TOTAL + ${COUNTS[$c]})); done

if [ "$TOTAL" -eq 0 ]; then
  printf 'OK: لا أنماط أخطاء بوابة/MCP في النطاق\n'
  exit 0
fi

printf 'إشارات إجمالية: %s\n' "$TOTAL"
for c in "${ORDER[@]}"; do
  if [ "${COUNTS[$c]}" -gt 0 ]; then
    printf '\n[%s] - %s\n' "$c" "${COUNTS[$c]}"
    printf '   عينة: %.120s\n' "${SAMPLES[$c]}"
  fi
done
printf '\nتلميح: تكرار 429 → راجع حدود المعدل؛ تكرار انقطاع MCP → استخدم بديل CLI المحلي (قسم Fallback في سياسة التشغيل).\n'
