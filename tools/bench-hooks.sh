#!/usr/bin/env bash
# قياس تكلفة استدعاء node داخل الـ hooks مقابل grep
set -uo pipefail
HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/hooks" && pwd)"
N=20
JSON='{"tool_input":{"command":"ls -la"}}'

ms_now() { date +%s%3N; }

echo "عدد التكرارات: $N"
echo ""

# ١) الـ hook الحالي (node)
start=$(ms_now)
for i in $(seq $N); do printf '%s' "$JSON" | bash "$HOOKS/block_dangerous.sh" >/dev/null 2>&1; done
end=$(ms_now)
node_total=$((end-start))
echo "block_dangerous (node): ${node_total}ms إجمالاً — $((node_total/N))ms للاستدعاء"

# ٢) محاكاة النسخة القديمة (grep فقط)
old_extract() {
  printf '%s' "$1" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"//;s/"$//'
}
start=$(ms_now)
for i in $(seq $N); do old_extract "$JSON" >/dev/null 2>&1; done
end=$(ms_now)
grep_total=$((end-start))
echo "استخراج grep فقط:      ${grep_total}ms إجمالاً — $((grep_total/N))ms للاستدعاء"

echo ""
echo "الفارق للاستدعاء الواحد: $(( (node_total-grep_total)/N ))ms"
echo "على 100 عملية أداة في جلسة: ~$(( (node_total-grep_total)*100/N/1000 )) ثانية إضافية"
