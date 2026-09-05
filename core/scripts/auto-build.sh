#!/usr/bin/env bash
# ============================================================
# auto-build.sh — مناظر bash لـ auto-build.ps1 (macOS / Linux / Git Bash)
# يبني مشروعًا كاملًا من خطة — يشتغل في الخلفية بدون تدخلك.
#
# المناظرة كما استقرت في 3818def:
#   • المهلة الافتراضية 45 دقيقة (لا 8 ساعات) — وكيل غير مراقب على جهاز
#     المستخدم يجب أن يتوقف قبل أن يستهلك ليلة كاملة
#   • MaxSteps ملزم لا إرشادي: المراقبة تعدّ الخطوات من progress.md
#     وتوقف العملية عند التجاوز
#   • لا افتراض للصلاحيات: إن مُنع أمر يُسجَّل BLOCKED ولا يُلتفّ عليه
#
# الاستخدام:
#   ./auto-build.sh --description "وصف المشروع" [خيارات]
#
# الخيارات:
#   --project-dir <مسار>       مجلد المشروع (الافتراضي: المجلد الحالي)
#   --description "..."         وصف المشروع مباشر
#   --description-file <ملف>    وصف المشروع من ملف
#   --plan-file <اسم>            ملف الخطة (الافتراضي: PLAN.md)
#   --log-file <اسم>            ملف السجل (الافتراضي: auto-build-log.txt)
#   --progress-file <اسم>       ملف التقدم (الافتراضي: progress.md)
#   --max-steps <n>             أقصى عدد خطوات (الافتراضي: 20 — ملزم مع --monitor)
#   --timeout-minutes <n>       المهلة بالدقائق (الافتراضي: 45 — تُطبَّق مع --monitor)
#   --monitor                   تشغيل المراقبة بعد بدء البناء
#   --run-checklist             فحص checklist-ui على كل واجهة أثناء البناء
#   --loop-ready                تجهيز ملفات Loop Engineering بعد الاكتمال
#
# متغيرا بيئة للاختبار الآلي (لا تحتاجهما في الاستخدام العادي):
#   AUTO_BUILD_CHECK_INTERVAL   ثوانٍ بين فحوص المراقبة (الافتراضي: 60)
#   AUTO_BUILD_PLAN_INTERVAL    ثوانٍ بين فحوص اكتمال الخطة (الافتراضي: 30)
# ============================================================

set -uo pipefail

PROJECT_DIR="$(pwd)"
DESCRIPTION=""
DESCRIPTION_FILE=""
PLAN_FILE="PLAN.md"
LOG_FILE="auto-build-log.txt"
PROGRESS_FILE="progress.md"
MAX_STEPS=20
TIMEOUT_MINUTES=45
MONITOR=0
RUN_CHECKLIST=0
LOOP_READY=0

usage() {
  sed -n '3,38p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir)      PROJECT_DIR="$2"; shift 2 ;;
    --description)      DESCRIPTION="$2"; shift 2 ;;
    --description-file) DESCRIPTION_FILE="$2"; shift 2 ;;
    --plan-file)        PLAN_FILE="$2"; shift 2 ;;
    --log-file)         LOG_FILE="$2"; shift 2 ;;
    --progress-file)    PROGRESS_FILE="$2"; shift 2 ;;
    --max-steps)        MAX_STEPS="$2"; shift 2 ;;
    --timeout-minutes)  TIMEOUT_MINUTES="$2"; shift 2 ;;
    --monitor)          MONITOR=1; shift ;;
    --run-checklist)    RUN_CHECKLIST=1; shift ;;
    --loop-ready)       LOOP_READY=1; shift ;;
    -h|--help)           usage ;;
    *) printf 'خيار غير معروف: %s (جرّب --help)\n' "$1" >&2; exit 2 ;;
  esac
done

step()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$1"; }
okmsg() { printf '[%s] ✅ %s\n' "$(date +%H:%M:%S)" "$1"; }
wrnmsg(){ printf '[%s] ⚠️ %s\n' "$(date +%H:%M:%S)" "$1"; }
errmsg(){ printf '[%s] ❌ %s\n' "$(date +%H:%M:%S)" "$1"; }

CHECK_INTERVAL="${AUTO_BUILD_CHECK_INTERVAL:-60}"
PLAN_INTERVAL="${AUTO_BUILD_PLAN_INTERVAL:-30}"
START_TIME=$SECONDS
BUILD_ID="build-$(date +%Y%m%d-%H%M%S)"

# تنظيف ملفات البرومبت المؤقتة القديمة (أقدم من ساعة) من جلسات سابقة
find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'auto-build-prompt-*.txt' -mmin +60 -delete 2>/dev/null || true

# ─── ١. التحقق من المتطلبات ──────────────────────────────────────
step "🔍 التحقق من المتطلبات..."

command -v claude >/dev/null 2>&1 \
  || { errmsg "Claude Code غير موجود في PATH. تأكد من تثبيته."; exit 1; }
okmsg "Claude Code موجود: $(command -v claude)"

command -v git >/dev/null 2>&1 \
  || wrnmsg "Git غير موجود في PATH. سيشتغل بدون تحكم إصدارات."

[ -d "$PROJECT_DIR" ] || { errmsg "المجلد $PROJECT_DIR غير موجود."; exit 1; }
cd "$PROJECT_DIR" || exit 1
okmsg "المشروع: $PROJECT_DIR"

# ─── ٢. قراءة وصف المشروع ───────────────────────────────────────
step "📝 قراءة وصف المشروع..."

if [ -n "$DESCRIPTION_FILE" ] && [ -f "$DESCRIPTION_FILE" ]; then
  DESCRIPTION="$(cat "$DESCRIPTION_FILE")"
  okmsg "تم قراءة الوصف من الملف: $DESCRIPTION_FILE"
elif [ -z "$DESCRIPTION" ]; then
  errmsg "ما كتبت وصف المشروع. استعمل --description أو --description-file"
  exit 1
fi

# ─── ٣. إنشاء الخطة ─────────────────────────────────────────────
step "📋 إنشاء خطة المشروع ($PLAN_FILE)..."

if [ -f "$PLAN_FILE" ] && [ "$(wc -c < "$PLAN_FILE" | tr -d ' ')" -ge 50 ]; then
  okmsg "الخطة موجودة وجاهزة"
else
  PLAN_PROMPT="المهمة: أنشئ خطة مشروع تفصيلية جدًا بناءً على الوصف التالي.
لا تسألني أي سؤال. فقط اكتب الخطة.

وصف المشروع:
$DESCRIPTION

متطلبات الخطة:
- اكتب الخطة في ملف $PLAN_FILE في المجلد الحالي
- قسّمها لخطوات واضحة (step-by-step)
- كل خطوة: ماذا يُنفَّذ بالضبط، وأين الملفات، وماذا يُكتب
- أقصى عدد خطوات: $MAX_STEPS
- بعد كل خطوة، حدّث $PROGRESS_FILE (سجل ماذا حدث)
- أول خطوة: تحضير البيئة (مجلدات، شجرة المشروع)
- آخر خطوة: اختبار أن كل شيء يعمل
- حدد لكل خطوة ما يعتبر «اكتمال»
- لا تستخدم مكتبات خارجية غير مثبتة

اللغة: العربية"

  PROMPT_FILE="$(mktemp "${TMPDIR:-/tmp}/auto-build-prompt-XXXXXXXX.txt")"
  printf '%s\n' "$PLAN_PROMPT" > "$PROMPT_FILE"
  claude -p < "$PROMPT_FILE" > "plan-generation-log.txt" 2> "plan-generation-errors.txt" &
  PLAN_PID=$!
  step "جاري توليد الخطة (PID: $PLAN_PID)... (انتظر)"

  WAIT=0
  while [ "$WAIT" -lt 6 ]; do
    sleep "$PLAN_INTERVAL"
    WAIT=$((WAIT + 1))
    if [ -f "$PLAN_FILE" ] && [ "$(wc -c < "$PLAN_FILE" | tr -d ' ')" -gt 100 ]; then
      okmsg "تم إنشاء $PLAN_FILE"
      break
    fi
    if [ "$WAIT" -ge 6 ]; then
      wrnmsg "الخطة ما اكتملت خلال المهلة. أكمل باللي موجود."
    fi
  done
  kill "$PLAN_PID" 2>/dev/null || true
  wait "$PLAN_PID" 2>/dev/null || true

  # خطة افتراضية عند تعذّر التوليد
  if [ ! -f "$PLAN_FILE" ] || [ "$(wc -c < "$PLAN_FILE" | tr -d ' ')" -lt 50 ]; then
    wrnmsg "إنشاء خطة افتراضية..."
    cat > "$PLAN_FILE" <<DEOF
# خطة المشروع

## الوصف
$DESCRIPTION

## البيئة
- الأدوات: Node.js, Git, Claude Code

## الخطوات

### 1. إعداد البيئة
- أنشئ شجرة المجلدات الأساسية
- حضّر package.json أو ملفات الإعداد
- **اكتمال:** مجلدات جاهزة + dependencies مثبتة

### 2. الهيكل الأساسي
- أنشئ الملفات الرئيسية
- حضّر المسارات (routing)
- **اكتمال:** كل الملفات الهيكلية موجودة

### 3. المكونات والصفحات
- نفّذ الصفحات حسب الوصف
- أضف المكونات المطلوبة
- **اكتمال:** كل الصفحات تعرض محتوى

### 4. ربط البيانات
- أضف API / Database
- اربط الواجهة بالبيانات
- **اكتمال:** البيانات تظهر في الصفحات

### 5. اختبار وتحسين
- اختبر كل صفحة
- صحّح الأخطاء
- **اكتمال:** كل شيء يعمل

## التعليمات
- نفّذ الخطوات بالترتيب
- بعد كل خطوة، سجّل في $PROGRESS_FILE
- لا تسأل المستخدم أي سؤال
DEOF
    okmsg "تم إنشاء خطة افتراضية"
  fi
fi

# ─── ٤. إنشاء progress.md ───────────────────────────────────────
cat > "$PROGRESS_FILE" <<PGEOF
# progress.md

**المشروع:** $(basename "$PROJECT_DIR")
**معرّف البناء:** $BUILD_ID
**تاريخ البداية:** $(date '+%Y-%m-%d %H:%M')
**الحالة:** ⏳ قيد التنفيذ
**آخر تحديث:** $(date '+%Y-%m-%d %H:%M:%S')

## الخطوات

| # | الحالة | الوصف |
|---|--------|-------|
PGEOF
okmsg "تم إنشاء $PROGRESS_FILE"

# ─── ٥. تشغيل البناء في الخلفية ─────────────────────────────────
step "🚀 تشغيل البناء في الخلفية..."

EXTRA_INSTRUCTIONS=""

if [ "$RUN_CHECKLIST" = "1" ]; then
  EXTRA_INSTRUCTIONS+="

قواعد جودة الواجهات (checklist-ui):
- بعد بناء كل صفحة أو مكون واجهة، طبّق فحص /checklist-ui عليها
- افحص: الألوان (custom properties فقط، تباين ≥ 4.5:1)، الطوبوغرافيا (عناوين roman، بدون أزرار بسطرين)، التخطيط (لا horizontal scroll، 4 شاشات)، التفاعل (focus ring، 8 حالات)، المحظورات (لا أرقام مزيفة، لا كروم مزيف)
- إذا فشل أي بند، أصلحه فورًا ولا تنتقل للخطوة التالية
- سجّل نتيجة الفحص في $PROGRESS_FILE تحت قسم «جودة الواجهة»
- إذا تجاوزت بندًا لأنه لا ينطبق، اشرح لماذا في سطر واحد"
fi

if [ "$LOOP_READY" = "1" ]; then
  EXTRA_INSTRUCTIONS+="

تجهيز Loop Engineering (بعد آخر خطوة):
- أنشئ مجلد .loop/ في جذر المشروع
- أنشئ ملف .loop/config.yaml بالأنماط الأساسية: daily-triage (L1) و dependency-sweeper (L1 patch-only)
- أضف ملف .loop/gate.yaml بسيط: allowlist للمجلدات (src/, lib/, components/) و denylist للمجلدات الحساسة (.env, node_modules, .git)
- اكتب في $PROGRESS_FILE قسم «جاهزية Loop Engineering» مع النتيجة
- اكتب: «لتفعيل المراقبة: شغّل npx @cobusgreyling/loop-init --from-config .loop/config.yaml»"
fi

BUILD_PROMPT="اقرأ الملف $PLAN_FILE في المجلد الحالي.

نفّذ كل الخطوات في الخطة بالترتيب. لا تخط أي خطوة.

قواعد صارمة:
- لا تسألني أي سؤال نهائيًا
- لا تفترض أن أي صلاحية ممنوحة. إن مُنع أمر، سجّل السبب في $PROGRESS_FILE واكتب BLOCKED بدل الالتفاف عليه
- إذا صار خطأ، سجله في $PROGRESS_FILE وحاول تكمل
- إذا ما عرفت تكمل، اكتب BLOCKED: [السبب] في $PROGRESS_FILE وتوقف
- بعد كل خطوة كاملة، حدّث $PROGRESS_FILE بخلاصة
- في $PROGRESS_FILE، اكتب لكل خطوة: تم / فشل / قيد التنفيذ / ملخص
- إذا خلصت كل الخطوات، اكتب DONE في $PROGRESS_FILE
- كل 3 خطوات، خلّص ملخص عام في $PROGRESS_FILE
$EXTRA_INSTRUCTIONS
الحد الأقصى $MAX_STEPS خطوة. لا تسوي أكثر من كذا.

ابدأ الآن."

PROMPT_FILE="$(mktemp "${TMPDIR:-/tmp}/auto-build-prompt-XXXXXXXX.txt")"
printf '%s\n' "$BUILD_PROMPT" > "$PROMPT_FILE"
claude -p < "$PROMPT_FILE" > "$LOG_FILE" 2> "${LOG_FILE%.txt}-errors.txt" &
CHILD_PID=$!
okmsg "✅ البناء شغال في الخلفية (PID: $CHILD_PID)"

# ─── ٦. معلومات للمستخدم ────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo "  🤖 بناء المشروع شغال في الخلفية"
echo "════════════════════════════════════════"
echo ""
echo "  📁 المشروع:     $PROJECT_DIR"
echo "  🆔 البناء:      $BUILD_ID"
echo "  🧵 PID:         $CHILD_PID"
echo "  📝 سجل:         $LOG_FILE"
echo "  📊 التقدم:      $PROGRESS_FILE"
echo "  ⏰ وقت البدء:   $(date +%H:%M:%S)"
echo "  ⏳ المهلة:      $TIMEOUT_MINUTES دقيقة"
echo ""
echo "  أوامر المراقبة:"
echo "  tail -n 20 $LOG_FILE        ← آخر 20 سطر"
echo "  cat $PROGRESS_FILE           ← التقدم الحالي"
echo "  kill $CHILD_PID         ← إيقاف البناء"
echo ""

# ─── ٧. مراقبة اختيارية ─────────────────────────────────────────
if [ "$MONITOR" = "1" ]; then
  step "👁️ تشغيل المراقبة..."
  wrnmsg "اضغط Ctrl+C لإيقاف المراقبة (البناء يظل شغال)"
  echo ""

  LAST_LEN=-1
  while :; do
    sleep "$CHECK_INTERVAL"

    # تحقق من سجل التقدم
    if [ -f "$PROGRESS_FILE" ]; then
      PROG="$(cat "$PROGRESS_FILE" 2>/dev/null || true)"
      LEN=${#PROG}
      if [ -n "$PROG" ] && [ "$LEN" != "$LAST_LEN" ]; then
        LAST_LEN=$LEN
        echo ""
        step "📊 تحديث التقدم:"
        printf '%s\n' "$PROG" | grep -E '(تم|فشل|BLOCKED|DONE|قيد|ملخص)' | sed 's/^/  /' || true

        # تحقق من الاكتمال
        if grep -q 'DONE' "$PROGRESS_FILE"; then
          echo ""
          okmsg "🎉 البناء اكتمل! افتح $LOG_FILE للتفاصيل الكاملة"
          exit 0
        fi
        if grep -q 'BLOCKED' "$PROGRESS_FILE"; then
          echo ""
          errmsg "⛔ البناء توقف! راجع $PROGRESS_FILE"
          exit 1
        fi
      fi
    fi

    # حدّ الخطوات — ملزم لا إرشادي. progress.md يسجّل سطراً لكل خطوة منجزة،
    # فنعدّها ونوقف العملية عند التجاوز بدل الاكتفاء بذكر الحد في البرومبت.
    if [ -f "$PROGRESS_FILE" ]; then
      STEP_COUNT="$(grep -cE '^[[:space:]]*([-*][[:space:]]*)?(\[[xX ]+\]|الخطوة|Step)[[:space:]]' "$PROGRESS_FILE" 2>/dev/null || true)"
      STEP_COUNT="${STEP_COUNT:-0}"
      if [ "$STEP_COUNT" -gt "$MAX_STEPS" ]; then
        wrnmsg "🚧 تجاوز حدّ الخطوات ($STEP_COUNT > $MAX_STEPS) — إيقاف البناء"
        if kill "$CHILD_PID" 2>/dev/null; then
          wrnmsg "  تم إيقاف العملية $CHILD_PID"
        else
          wrnmsg "  ما قدرت أوقف العملية $CHILD_PID (يمكن خلصت)"
        fi
        exit 1
      fi
    fi

    # تحقق من انتهاء المهلة
    ELAPSED=$((SECONDS - START_TIME))
    if [ "$ELAPSED" -gt $((TIMEOUT_MINUTES * 60)) ]; then
      wrnmsg "⏰ المهلة انتهت ($TIMEOUT_MINUTES دقيقة) — إيقاف البناء"
      if kill "$CHILD_PID" 2>/dev/null; then
        wrnmsg "  تم إيقاف العملية $CHILD_PID"
      else
        wrnmsg "  ما قدرت أوقف العملية $CHILD_PID (يمكن خلصت)"
      fi
      exit 1
    fi

    # تحقق من أن العملية لسه حية
    if ! kill -0 "$CHILD_PID" 2>/dev/null; then
      echo ""
      okmsg "⚙️ عملية البناء انتهت! راجع $LOG_FILE"
      exit 0
    fi

    printf '.' >&2
  done
fi

# ─── ٨. تذكير نهائي ───────────────────────────────────────────────
echo ""
echo "  💡 ارجع لاحقًا وشغّل:"
echo "     tail -n 50 $LOG_FILE"
echo "     cat $PROGRESS_FILE"
echo ""
