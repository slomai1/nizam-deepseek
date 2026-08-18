#!/usr/bin/env bash
# block_dangerous.sh — PreToolUse (Bash)
# يمنع 20+ أمر خطير قبل التنفيذ
# الاستخراج عبر node (JSON حقيقي) — يعالج الاقتباسات المهرّبة التي يكسرها grep

set -euo pipefail

INPUT=$(cat)

# استخراج الأمر عبر node — يحلل JSON فعلياً لا نصاً
COMMAND=$(printf '%s' "$INPUT" | node -e '
let s = "";
process.stdin.on("data", (d) => (s += d));
process.stdin.on("end", () => {
  try {
    const j = JSON.parse(s);
    const c = (j.tool_input && j.tool_input.command) || j.command || "";
    process.stdout.write(String(c));
  } catch (e) {
    process.stdout.write("");
  }
});
')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# ─── قائمة الأوامر الخطيرة (bash + PowerShell + sh) ───
DANGEROUS=(
  'rm[[:space:]]+-rf[[:space:]]+/'
  'rm[[:space:]]+-rf[[:space:]]+~'
  'rm[[:space:]]+-rf[[:space:]]+\$HOME'
  # النقطة وحدها فقط (نهاية أو مسافة) — لا نمنع rm -rf .next أو .cache أو ./build
  'rm[[:space:]]+-rf[[:space:]]+\.[[:space:]]*$'
  'rm[[:space:]]+-rf[[:space:]]+\./?[[:space:]]*(;|&&|\|)'
  'rm[[:space:]]+-rf[[:space:]]+\.\.[[:space:]]*$'
  'rm[[:space:]]+-rf[[:space:]]+\*[[:space:]]*$'
  'git[[:space:]]+push[[:space:]]+(--force|-f)'
  'git[[:space:]]+reset[[:space:]]+--hard'
  'git[[:space:]]+clean[[:space:]]+-fdx?'
  'git[[:space:]]+branch[[:space:]]+-D'
  'git[[:space:]]+checkout[[:space:]]+\.'
  'git[[:space:]]+restore[[:space:]]+\.'
  'DROP[[:space:]]+TABLE'
  'DROP[[:space:]]+DATABASE'
  'TRUNCATE[[:space:]]+TABLE'
  'DELETE[[:space:]]+FROM[[:space:]]+[a-z_]+[[:space:]]*;?[[:space:]]*$'
  'chmod[[:space:]]+(-R[[:space:]]+)?777'
  'chown[[:space:]]+-R[[:space:]]+root'
  'npm[[:space:]]+publish'
  'mkfs\.'
  'dd[[:space:]]+if='
  ':(){ :|:& };:'   # fork bomb
  '>\s*\/dev\/sda'
  'format[[:space:]]+C:'
  'del[[:space:]]+[\/f][[:space:]]+[\/s][[:space:]]+[\/q][[:space:]]+C:\\'
  # تنفيذ مباشر من الإنترنت — سطح هجوم
  '(curl|wget)[[:space:]]+[^|]*[|][[:space:]]*(sudo[[:space:]]+)?(ba)?sh'
  # PowerShell — تغطية الأنماط السامة
  'Remove-Item[[:space:]]+-Recurse[[:space:]]+-Force[[:space:]]+[A-Z]:[\\/]'
  'Remove-Item[[:space:]]+-Recurse[[:space:]]+-Force[[:space:]]+\$env:'
  'Format-Volume[[:space:]]+-DriveLetter'
  'Clear-Content[[:space:]]+-Path[[:space:]]+\$env:'
  'Set-ExecutionPolicy[[:space:]]+-Scope[[:space:]]+CurrentUser[[:space:]]+-ExecutionPolicy[[:space:]]+Bypass'
  # كتابة فوق ملفات حساسة
  '>[[:space:]]+/etc/passwd'
  '>[[:space:]]+/etc/shadow'
  '>[[:space:]]+~/.bashrc'
  '>[[:space:]]+~/.zshrc'
)

for pattern in "${DANGEROUS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "❌ أمر خطير ممنوع: $COMMAND" >&2
    echo "   النمط المطابق: $pattern" >&2
    exit 2
  fi
done

exit 0
