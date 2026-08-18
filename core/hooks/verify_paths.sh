#!/usr/bin/env bash
# verify_paths.sh — PreToolUse (Edit/Write/Read/MultiEdit)
# طبقة منع هلوسة: يمسك المسار المختلق قبل أن يلمسه النموذج

set -euo pipefail

INPUT=$(cat)

# اسم الأداة
TOOL=$(echo "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"tool_name"[[:space:]]*:[[:space:]]*"//;s/"$//')

# مسار الملف
FILE=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')

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
