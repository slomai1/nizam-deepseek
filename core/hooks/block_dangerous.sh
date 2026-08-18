#!/usr/bin/env bash
# block_dangerous.sh — PreToolUse (Bash|PowerShell)
# يمنع الأوامر الخطيرة قبل التنفيذ
#
# مبدآن أمنيان:
#   1. fail-closed: إذا تعذّر تحليل JSON نفحص النص الخام بدل تمرير الأمر بلا فحص
#   2. الأنماط تُختبر فعلياً (راجع .test-hooks.sh) — لا نمط بلا اختبار يثبت مطابقته

set -uo pipefail

INPUT=$(cat)

# استخراج الأمر عبر node (JSON حقيقي) — يعالج الاقتباسات المهرّبة التي يكسرها grep
# عند فشل التحليل نطبع __PARSE_FAILED__ لنفحص النص الخام بدل المرور بصمت
COMMAND=$(printf '%s' "$INPUT" | node -e '
let s = "";
process.stdin.on("data", (d) => (s += d));
process.stdin.on("end", () => {
  try {
    const j = JSON.parse(s);
    const ti = j.tool_input || {};
    // Bash يستخدم command · PowerShell قد يستخدم command أيضاً
    const c = ti.command || j.command || "";
    process.stdout.write(String(c));
  } catch (e) {
    process.stdout.write("__PARSE_FAILED__");
  }
});
' 2>/dev/null || printf '__PARSE_FAILED__')

# fail-closed: تعذّر التحليل (أو غياب node) → نفحص المدخل الخام كاملاً
if [ "$COMMAND" = "__PARSE_FAILED__" ] || [ -z "${COMMAND}" ]; then
  if [ "$COMMAND" = "__PARSE_FAILED__" ]; then
    COMMAND="$INPUT"
  else
    exit 0   # تحليل ناجح بلا أمر — لا شيء لفحصه
  fi
fi

# ─── تقليل الإيجابيات الكاذبة ───
# نص التوثيق (رسائل commit، heredoc، سلاسل مقتبسة) يذكر أوامر خطرة كأمثلة
# دون تنفيذها. نجرّد هذه المقاطع قبل الفحص حتى لا يُمنع توثيقٌ بريء.
# التجريد يقتصر على heredoc ورسائل commit — لا يطال الأمر المنفَّذ نفسه.
SCAN="$COMMAND"
if printf '%s' "$SCAN" | grep -qE '^[[:space:]]*git[[:space:]]+commit'; then
  # نحذف محتوى heredoc ورسائل -m من نطاق الفحص
  SCAN=$(printf '%s' "$SCAN" | sed -e "s/<<'\?EOF'\?.*//" -e 's/-m[[:space:]]*"[^"]*"//g' -e "s/-m[[:space:]]*'[^']*'//g")
fi

# ─── الأوامر الخطيرة ───
DANGEROUS=(
  # حذف جذري
  'rm[[:space:]]+-rf[[:space:]]+/'
  'rm[[:space:]]+-rf[[:space:]]+~'
  'rm[[:space:]]+-rf[[:space:]]+\$HOME'
  # النقطة/النقطتان وحدهما — لا نمنع rm -rf .next أو ./build
  'rm[[:space:]]+-rf[[:space:]]+\.[[:space:]]*$'
  'rm[[:space:]]+-rf[[:space:]]+\.\.[[:space:]]*$'
  'rm[[:space:]]+-rf[[:space:]]+\./?[[:space:]]*(;|&&)'
  # dot-glob: rm -rf * و ./* و ../*  (كانت تتسلل قبل)
  'rm[[:space:]]+-rf[[:space:]]+(\.\.?/)?\*([[:space:]]|$|;|&)'
  # git مدمّر
  'git[[:space:]]+push[[:space:]]+(--force|-f)'
  'git[[:space:]]+reset[[:space:]]+--hard'
  'git[[:space:]]+clean[[:space:]]+-fdx?'
  'git[[:space:]]+branch[[:space:]]+-D'
  'git[[:space:]]+checkout[[:space:]]+\.'
  'git[[:space:]]+restore[[:space:]]+\.'
  # قواعد بيانات
  'DROP[[:space:]]+TABLE'
  'DROP[[:space:]]+DATABASE'
  'TRUNCATE[[:space:]]+TABLE'
  # صلاحيات وأقراص
  'chmod[[:space:]]+(-R[[:space:]]+)?777'
  'chown[[:space:]]+-R[[:space:]]+root'
  'mkfs\.'
  'dd[[:space:]]+if='
  '>[[:space:]]*/dev/sd[a-z]'
  'format[[:space:]]+[A-Z]:'
  # fork bomb — الأقواس مهرّبة ليطابق النص الحرفي (كان نمطاً ميتاً قبل)
  ':\(\)[[:space:]]*\{.*:\|:&'
  # تنفيذ مباشر من الإنترنت
  '(curl|wget)[[:space:]]+[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh'
  # نشر غير مقصود
  'npm[[:space:]]+publish'
  # PowerShell — يعمل فقط إذا كان الـ hook مسجّلاً على matcher يشمل PowerShell
  'Remove-Item[[:space:]]+.*-Recurse[[:space:]]+.*-Force[[:space:]]+[A-Z]:[\\/]'
  'Remove-Item[[:space:]]+.*-Recurse[[:space:]]+.*-Force[[:space:]]+\$env:'
  'Format-Volume'
  'Set-ExecutionPolicy[[:space:]]+.*Bypass'
  # كتابة فوق ملفات حساسة
  '>[[:space:]]*/etc/(passwd|shadow)'
  '>[[:space:]]*~/\.(bashrc|zshrc|profile)'
)

# تمريرة grep واحدة بكل الأنماط مجتمعة — استدعاء grep لكل نمط كان يكلّف
# ~104ms على Windows، أي >3 ثوانٍ لـ 31 نمطاً في كل أمر
JOINED=$(printf '%s|' "${DANGEROUS[@]}")
JOINED="${JOINED%|}"

if printf '%s' "$SCAN" | grep -qE "$JOINED"; then
  # نحدد النمط المطابق فقط عند الرفض (مسار نادر — تكلفته مقبولة)
  for pattern in "${DANGEROUS[@]}"; do
    if printf '%s' "$SCAN" | grep -qE "$pattern"; then
      echo "❌ أمر خطير ممنوع" >&2
      echo "   النمط المطابق: $pattern" >&2
      exit 2
    fi
  done
  echo "❌ أمر خطير ممنوع" >&2
  exit 2
fi

exit 0
