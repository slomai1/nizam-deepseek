#!/usr/bin/env bash
# auto_format.sh — PostToolUse (Edit/Write/MultiEdit)
# يشغّل أداة التنسيق المناسبة حسب امتداد الملف
# md و json مستبعدان عمداً — لا نُفسد محتوى مكتوباً/مُنسّقاً يدوياً

set -euo pipefail

INPUT=$(cat)

# استخراج مسار الملف عبر node (JSON حقيقي)
FILE=$(printf '%s' "$INPUT" | node -e '
let s = "";
process.stdin.on("data", (d) => (s += d));
process.stdin.on("end", () => {
  try {
    const j = JSON.parse(s);
    const f = (j.tool_input && j.tool_input.file_path) || j.file_path || "";
    process.stdout.write(String(f));
  } catch (e) {
    process.stdout.write("");
  }
});
')

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  exit 0
fi

EXT="${FILE##*.}"
NAME=$(basename "$FILE")

# ─── JavaScript / TypeScript / CSS (md و json مستبعدان عمداً) ───
case "$EXT" in
  js|jsx|ts|tsx|mjs|cjs|css|scss|less|html|vue|svelte|astro)
    if command -v npx &>/dev/null; then
      npx --yes prettier --write "$FILE" 2>/dev/null || true
    fi
    exit 0
    ;;
esac

# ─── PHP ───
case "$EXT" in
  php|phtml)
    if command -v php-cs-fixer &>/dev/null; then
      php-cs-fixer fix "$FILE" --quiet 2>/dev/null || true
    elif command -v phpcbf &>/dev/null; then
      phpcbf --quiet "$FILE" 2>/dev/null || true
    fi
    exit 0
    ;;
esac

# ─── Dart ───
case "$EXT" in
  dart)
    if command -v dart &>/dev/null; then
      dart format "$FILE" 2>/dev/null || true
    fi
    exit 0
    ;;
esac

exit 0
