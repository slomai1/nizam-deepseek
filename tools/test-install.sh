#!/usr/bin/env bash
# اختبار سلامة التركيب:
#   • تركيب أول ينشئ الملفات
#   • تركيب ثانٍ بلا --force لا يدهس ملفاً عدّله المستخدم
#   • --force يستبدل
#   • --minimal بلا ملحقات ولا أسواق
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$REPO/.install-sandbox"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ✗ %s — %s\n' "$1" "${2:-}"; }
topath() { command -v cygpath >/dev/null 2>&1 && cygpath -m "$1" || printf '%s' "$1"; }

run_install() { # run_install <dir> [args...]
  local dir="$1"; shift
  CLAUDE_CONFIG_DIR="$dir" bash "$REPO/install/install.sh" --no-backup --skip-claude-check "$@" >/dev/null 2>&1
}

rm -rf "$SANDBOX"; mkdir -p "$SANDBOX"
D="$SANDBOX/claude"

echo "=== تركيب أول ==="
run_install "$D"
[ -f "$D/CLAUDE.md" ]           && ok "CLAUDE.md أُنشئ"        || bad "CLAUDE.md"
[ -f "$D/settings.json" ]       && ok "settings.json أُنشئ"    || bad "settings.json"
[ "$(ls "$D/hooks"/*.sh 2>/dev/null | wc -l)" = "5" ] && ok "5 خطافات" || bad "الخطافات"
[ -f "$D/data/deepseek.db" ]    && ok "قاعدة الذاكرة"          || bad "القاعدة"

echo ""
echo "=== تركيب ثانٍ بلا --force: لا يدهس تعديلات المستخدم ==="
MARK="# تعديل المستخدم — يجب ألا يُدهس"
printf '%s\n' "$MARK" > "$D/hooks/block_dangerous.sh"
printf '%s\n' "$MARK" > "$D/CLAUDE.md"
printf '%s\n' "$MARK" > "$D/commands/mem-load.md"
run_install "$D"
grep -q "$MARK" "$D/hooks/block_dangerous.sh" && ok "خطاف معدَّل بقي كما هو"  || bad "الخطاف" "دُهس"
grep -q "$MARK" "$D/CLAUDE.md"                && ok "CLAUDE.md معدَّل بقي"    || bad "CLAUDE.md" "دُهس"
grep -q "$MARK" "$D/commands/mem-load.md"     && ok "أمر معدَّل بقي"          || bad "الأمر" "دُهس"

echo ""
echo "=== ملف جديد يُضاف رغم وجود ملفات أخرى ==="
rm -f "$D/commands/mem-save.md"
run_install "$D"
[ -f "$D/commands/mem-save.md" ] && ok "الملف الناقص أُعيد" || bad "الإضافة" "لم يُضف"
grep -q "$MARK" "$D/CLAUDE.md"   && ok "وفي الوقت نفسه المعدَّل لم يُلمس" || bad "الحماية" "دُهس"

echo ""
echo "=== --force يستبدل ==="
run_install "$D" --force
grep -q "$MARK" "$D/CLAUDE.md" && bad "--force" "لم يستبدل" || ok "--force استبدل المعدَّل"
grep -q "block_dangerous" "$D/hooks/block_dangerous.sh" && ok "الخطاف استُعيد لنسخة المستودع" || bad "الخطاف" "لم يُستعد"

echo ""
echo "=== --minimal بلا ملحقات ==="
DM="$SANDBOX/claude-minimal"
run_install "$DM" --minimal
node -e '
const fs=require("fs");
const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const plugins=Object.keys(s.enabledPlugins||{}).length;
const markets=Object.keys(s.extraKnownMarketplaces||{}).length;
if (plugins===0 && markets===0) process.exit(0);
console.error("plugins="+plugins+" markets="+markets);
process.exit(1);
' "$(topath "$DM/settings.json")" && ok "بلا ملحقات ولا أسواق" || bad "--minimal" "الملحقات موجودة"
[ "$(ls "$DM/hooks"/*.sh 2>/dev/null | wc -l)" = "5" ] && ok "النواة كاملة رغم --minimal" || bad "النواة"
[ -f "$DM/data/deepseek.db" ] && ok "الذاكرة مهيّأة رغم --minimal" || bad "الذاكرة"

echo ""
echo "=== التركيب الكامل يفعّل الملحقات ==="
DF="$SANDBOX/claude-full"
run_install "$DF"
node -e '
const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
process.exit(Object.keys(s.enabledPlugins||{}).length>0 ? 0 : 1);
' "$(topath "$DF/settings.json")" && ok "الملحقات مفعّلة بلا --minimal" || bad "التركيب الكامل"

rm -rf "$SANDBOX"
echo ""
echo "========================================"
printf 'نجح: %s | فشل: %s\n' "$PASS" "$FAIL"
[ "$FAIL" = "0" ] && exit 0 || exit 1
