#!/usr/bin/env bash
# verify_paths.sh — PreToolUse (Edit/Write/Read/MultiEdit)
# طبقة منع هلوسة: يمسك المسار المختلق قبل أن يلمسه النموذج

set -euo pipefail

INPUT=$(cat)

# استخراج عبر node (JSON حقيقي — يعالج الاقتباسات المهرّبة التي يكسرها grep)
# كل حقل في سطر منفصل لئلا تنكسر المسارات ذات المسافات
OUT=$(printf '%s' "$INPUT" | node -e '
let s = "";
process.stdin.on("data", (d) => (s += d));
process.stdin.on("end", () => {
  try {
    const j = JSON.parse(s);
    const tool = j.tool_name || "";
    const f = (j.tool_input && j.tool_input.file_path) || j.file_path || "";
    process.stdout.write(tool + "\n" + f);
  } catch (e) {
    process.stdout.write("\n");
  }
});
')
TOOL=$(printf '%s\n' "$OUT" | sed -n '1p')
FILE=$(printf '%s\n' "$OUT" | sed -n '2p')

if [ -z "$FILE" ]; then
  exit 0
fi

# تطبيع المسار: شرطات Windows (مفردة أو مزدوجة من تهريب JSON) → أمامية
NORM=$(printf '%s' "$FILE" | sed 's/\\\+/\//g')

case "$TOOL" in
  Read|Edit|MultiEdit)
    if [ ! -f "$NORM" ]; then
      echo "⚠️ هلوسة مسار محتملة: الملف غير موجود — لا تلمسه قبل التحقق" >&2
      echo "   المسار: $FILE" >&2
      echo "   تحقق بـ Glob/Grep أولاً، ولا تفترض وجود ملف لم تتأكد منه." >&2
      exit 2
    fi
    ;;
  Write)
    DIR=$(dirname "$NORM")
    if [ ! -d "$DIR" ]; then
      echo "⚠️ هلوسة مسار محتملة: المجلد الأب غير موجود" >&2
      echo "   المسار: $FILE" >&2
      echo "   أنشئ المجلد بـ mkdir أولاً، أو صحّح المسار." >&2
      exit 2
    fi
    ;;
esac

exit 0
