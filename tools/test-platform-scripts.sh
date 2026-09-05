#!/usr/bin/env bash
# ============================================================
# اختبار مناظر يونكس للسكربتات + فحص أسماء النماذج (تنفيذ القضية #2)
#
#   • auto-build.sh: المهلة 45 دقيقة افتراضاً، MaxSteps ملزم فعلياً
#     (يقتل العملية عند التجاوز)، BLOCKED، وبلا --monitor يبدأ ويسلم
#   • deepseek-logs.sh: التصنيفات الخمس، العدّ، ورموز الخروج
#   • check-model-names.sh: كشف الاسم التجريبي المفقود، و--strict
#
# الاستخدام: bash tools/test-platform-scripts.sh
# ============================================================
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SB="$REPO/.platform-sandbox"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ✗ %s — %s\n' "$1" "${2:-}"; }

rm -rf "$SB"; mkdir -p "$SB/bin" "$SB/proj"

echo "=== صياغة المناظر ==="
for f in core/scripts/auto-build.sh core/scripts/deepseek-logs.sh install/check-model-names.sh; do
  bash -n "$REPO/$f" 2>/dev/null && ok "bash -n $f" || bad "صياغة $f"
done

echo ""
echo "=== auto-build: العقود الموثقة ==="
HELP_OUT="$(bash "$REPO/core/scripts/auto-build.sh" --help 2>&1)"
echo "$HELP_OUT" | grep -q "45" && ok "المهلة الافتراضية 45 دقيقة موثقة" || bad "المهلة" "45 غائبة من --help"
echo "$HELP_OUT" | grep -q "max-steps" && ok "MaxSteps موثق" || bad "MaxSteps" "غير موثق"

# وكيل claude مزيف: يفرّق بين برومبت الخطة وبرومبت البناء من stdin
cat > "$SB/bin/claude" <<'FAKE'
#!/usr/bin/env bash
PROMPT="$(cat)"
case "$PROMPT" in
  *"أنشئ خطة"*)
    cat > PLAN.md <<'PLAN'
# خطة تجريبية طويلة بما يككي لتجاوز حد المئة بايت في فحص اكتمال الخطة
خطوة أولى: تهيئة البيئة والمجلدات وملفات الإعداد
خطوة ثانية: بناء الهيكل الأساسي والصفحات والمكونات
PLAN
    ;;
  *)
    # برومبت البناء: يسجّل خطوات منجزة ثم ينام — لمحاكاة وكيل لا يتوقف
    for i in $(seq 1 25); do
      printf -- "- [x] الخطوة %s: أنجزت\n" "$i" >> progress.md
    done
    sleep 600
    ;;
esac
FAKE
chmod +x "$SB/bin/claude"

echo ""
echo "=== auto-build: MaxSteps ملزم — يقتل العملية عند التجاوز ==="
export PATH="$SB/bin:$PATH"
export AUTO_BUILD_CHECK_INTERVAL=1
export AUTO_BUILD_PLAN_INTERVAL=1
( cd "$SB/proj" && bash "$REPO/core/scripts/auto-build.sh" \
    --description "مشروع تجريبي" --max-steps 3 --timeout-minutes 45 --monitor \
    > "$SB/out-steps.txt" 2>&1 )
CODE=$?
if grep -q "تجاوز حدّ الخطوات" "$SB/out-steps.txt"; then
  ok "كشف تجاوز الحد (25 خطوة > 3) وأوقف البناء"
else
  bad "MaxSteps" "لم يُوقف عند التجاوز"
fi
[ "$CODE" = "1" ] && ok "رمز خروج 1 عند تجاوز الحد" || bad "رمز الخروج" "متوقع 1، جاء $CODE"

echo ""
echo "=== auto-build: المهلة تقتل فعلاً ==="
rm -rf "$SB/proj2"; mkdir -p "$SB/proj2"
( cd "$SB/proj2" && bash "$REPO/core/scripts/auto-build.sh" \
    --description "مشروع تجريبي" --max-steps 100 --timeout-minutes 0 --monitor \
    > "$SB/out-timeout.txt" 2>&1 )
CODE=$?
grep -q "المهلة انتهت" "$SB/out-timeout.txt" \
  && ok "انتهاء المهلة يوقف البناء" || bad "المهلة" "لم تُطبق"
[ "$CODE" = "1" ] && ok "رمز خروج 1 عند المهلة" || bad "رمز الخروج/المهلة" "جاء $CODE"

echo ""
echo "=== auto-build: بلا --monitor يبدأ في الخلفية ويسلّم ==="
rm -rf "$SB/proj3"; mkdir -p "$SB/proj3"
( cd "$SB/proj3" && bash "$REPO/core/scripts/auto-build.sh" \
    --description "مشروع تجريبي" --max-steps 5 \
    > "$SB/out-bg.txt" 2>&1 )
CODE=$?
[ "$CODE" = "0" ] && ok "يسلّم فوراً (exit 0) والبناء في الخلفية" || bad "بلا-مراقبة" "exit=$CODE"
grep -q "PID:" "$SB/out-bg.txt" && ok "يطبع PID العملية للمراقبة اليدوية" || bad "PID" "غائب"
pkill -f "sleep 600" 2>/dev/null || true

echo ""
echo "=== auto-build: BLOCKED يوقف المراقبة بخطأ ==="
rm -rf "$SB/proj4"; mkdir -p "$SB/proj4"
cat > "$SB/bin/claude" <<'FAKE2'
#!/usr/bin/env bash
PROMPT="$(cat)"
case "$PROMPT" in
  *"أنشئ خطة"*)
    printf '# خطة تجريبية كافية الطول لتجاوز فحص اكتمال الخطة بعدة أسطر إضافية\n' > PLAN.md
    ;;
  *)
    printf 'BLOCKED: صلاحية مرفوضة\n' >> progress.md
    sleep 600
    ;;
esac
FAKE2
chmod +x "$SB/bin/claude"
( cd "$SB/proj4" && bash "$REPO/core/scripts/auto-build.sh" \
    --description "مشروع تجريبي" --max-steps 5 --timeout-minutes 45 --monitor \
    > "$SB/out-blocked.txt" 2>&1 )
CODE=$?
grep -q "⛔ البناء توقف" "$SB/out-blocked.txt" \
  && ok "BLOCKED في progress.md يوقف المراقبة بخطأ" || bad "BLOCKED" "لم يُكتشف"
[ "$CODE" = "1" ] && ok "رمز خروج 1 عند BLOCKED" || bad "رمز/BLOCKED" "جاء $CODE"
pkill -f "sleep 600" 2>/dev/null || true

echo ""
echo "=== deepseek-logs: التصنيفات والعدّ ==="
FAKEHOME="$SB/home"; mkdir -p "$FAKEHOME/.claude"
cat > "$FAKEHOME/.claude/history.jsonl" <<HIST
{"t":"ok","msg":"session started normally"}
{"t":"e1","msg":"429 too many requests from gateway"}
{"t":"e2","msg":"request timed out after 30000ms"}
{"t":"e3","msg":"playwright mcp extension is not connected"}
{"t":"e4","msg":"upstream error 502 bad gateway retry"}
{"t":"e5","msg":"403 forbidden on admin endpoint"}
{"t":"ok","msg":"all good here"}
HIST

LOGOUT="$(CLAUDE_CONFIG_DIR="$FAKEHOME/.claude" bash "$REPO/core/scripts/deepseek-logs.sh" 500)"
echo "$LOGOUT" | grep -q "\[rate limit\] - 1"      && ok "rate limit: 1" || bad "rate limit" "العدّ خاطئ"
echo "$LOGOUT" | grep -q "\[timeout/connection\] - 1" && ok "timeout/connection: 1" || bad "timeout" "العدّ خاطئ"
echo "$LOGOUT" | grep -q "\[MCP not connected\] - 1" && ok "MCP not connected: 1" || bad "MCP" "العدّ خاطئ"
echo "$LOGOUT" | grep -q "\[gateway/upstream\] - 1" && ok "gateway/upstream: 1" || bad "gateway" "العدّ خاطئ"
echo "$LOGOUT" | grep -q "\[auth error\] - 1"       && ok "auth error: 1" || bad "auth" "العدّ خاطئ"
echo "$LOGOUT" | grep -q "إشارات إجمالية: 5"        && ok "الإجمالي 5" || bad "الإجمالي" "غير صحيح"

printf '{"m":"hello"}' > "$FAKEHOME/.claude/history.jsonl"
LOUT2="$(CLAUDE_CONFIG_DIR="$FAKEHOME/.claude" bash "$REPO/core/scripts/deepseek-logs.sh")"
echo "$LOUT2" | grep -q "OK: لا أنماط" && ok "ملف نظيف → OK" || bad "نظيف" "لم يعُد OK"

CLAUDE_CONFIG_DIR="$SB/nonexistent" bash "$REPO/core/scripts/deepseek-logs.sh" >/dev/null 2>&1
[ $? = "1" ] && ok "history.jsonl مفقود → exit 1" || bad "مفقود" "رمز خروج خاطئ"

echo ""
echo "=== check-model-names: كشف الاسم التجريبي المفقود ==="

# خادم محلي يقدم قائمة نماذج بلا الاسم التجريبي — يحاكي تغيير المزود
PORT_FILE="$SB/port"
node -e '
const http = require("http");
const srv = http.createServer((req, res) => {
  res.setHeader("Content-Type", "application/json");
  res.end(JSON.stringify({ data: [{ id: "deepseek-v4-pro" }, { id: "deepseek-v4-flash" }] }));
});
srv.listen(0, "127.0.0.1", () => {
  require("fs").writeFileSync(process.argv[1], String(srv.address().port));
});
' "$PORT_FILE" &
SRV_PID=$!
for i in $(seq 1 20); do [ -f "$PORT_FILE" ] && break; sleep 0.2; done
PORT="$(cat "$PORT_FILE")"

# قاعدة قالب ثابتة للاختبار — لا نقرأ settings.template.json الفعلي حتى
# لا يكسر تحديث المشروع لأسماء نماذجه هذا الاختبار
FIXTURE="$SB/fixture-models.json"
cat > "$FIXTURE" <<'FIX'
{
  "env": {
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-flash-vision-exp",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash[1m]"
  }
}
FIX

CMOUT="$(ANTHROPIC_AUTH_TOKEN="tok-local" bash "$REPO/install/check-model-names.sh" \
  --template "$FIXTURE" --base-url "http://127.0.0.1:$PORT" 2>&1)"
echo "$CMOUT" | grep -q "opus: deepseek-v4-pro\[1m\] متوفر" && ok "الاسم المستقر (pro) يمر" || bad "pro" "لم يُقبل"
echo "$CMOUT" | grep -q "sonnet: deepseek-v4-flash-vision-exp غير موجود" && ok "الاسم التجريبي (vision-exp) يُكشف" || bad "vision-exp" "لم يُكتشف"
echo "$CMOUT" | grep -q "docs/03" && ok "الرسالة تحيل إلى docs/03" || bad "الإحالة" "docs/03 غائبة"

bash "$REPO/install/check-model-names.sh" --template "$FIXTURE" \
  --base-url "http://127.0.0.1:$PORT" >/dev/null 2>&1 \
  && ok "افتراضياً استشاري (exit 0) رغم الاسم المفقود" || bad "استشاري" "فشل بلا --strict"

ANTHROPIC_AUTH_TOKEN="tok-local" bash "$REPO/install/check-model-names.sh" \
  --template "$FIXTURE" --base-url "http://127.0.0.1:$PORT" --strict >/dev/null 2>&1
[ $? = "1" ] && ok "--strict يفشل عند اسم مفقود" || bad "--strict" "لم يفشل"

NOKEY="$(bash "$REPO/install/check-model-names.sh" --template "$FIXTURE" --base-url "http://127.0.0.1:$PORT" 2>&1)"
echo "$NOKEY" | grep -q "لم نجد ANTHROPIC_AUTH_TOKEN" && ok "بلا مفتاح: تحذير وتخطٍّ" || bad "بلا-مفتاح" "لا تحذير"
kill "$SRV_PID" 2>/dev/null || true

rm -rf "$SB"
echo ""
echo "========================================"
printf 'نجح: %s | فشل: %s\n' "$PASS" "$FAIL"
[ "$FAIL" = "0" ] && exit 0 || exit 1
