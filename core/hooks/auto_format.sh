#!/usr/bin/env bash
# auto_format.sh — PostToolUse (Edit/Write/MultiEdit)
# يشغّل أداة التنسيق المناسبة حسب امتداد الملف

set -euo pipefail

INPUT=$(cat)

# استخراج مسار الملف من JSON المدخل
FILE=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  exit 0
fi

EXT="${FILE##*.}"
NAME=$(basename "$FILE")

# ─── JavaScript / TypeScript / CSS / JSON ───
case "$EXT" in
  js|jsx|ts|tsx|mjs|cjs|json|css|scss|less|html|md|yaml|yml|vue|svelte|astro)
    if command -v npx &>/dev/null; then
      npx --yes prettier --write "$FILE" 2>/dev/null && exit 0 || exit 0
    fi
    exit 0
    ;;
esac

# ─── PHP ───
case "$EXT" in
  php|phtml)
    if command -v php-cs-fixer &>/dev/null; then
      php-cs-fixer fix "$FILE" --quiet 2>/dev/null && exit 0 || exit 0
    elif command -v phpcbf &>/dev/null; then
      phpcbf --quiet "$FILE" 2>/dev/null && exit 0 || exit 0
    elif command -v npx &>/dev/null; then
      # prettier مع إضافة PHP plugin
      npx --yes prettier --write "$FILE" --plugin=@prettier/plugin-php 2>/dev/null && exit 0 || exit 0
    fi
    exit 0
    ;;
esac

# ─── Dart ───
case "$EXT" in
  dart)
    if command -v dart &>/dev/null; then
      dart format "$FILE" 2>/dev/null && exit 0 || exit 0
    fi
    exit 0
    ;;
esac

exit 0
