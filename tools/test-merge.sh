#!/usr/bin/env bash
# اختبار merge-settings — يثبت أن الدمج لا يوسّع صلاحيات المستخدم أبداً
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TPL="$REPO/templates/settings.template.json"
TMP="$REPO/.merge-test.json"
PASS=0; FAIL=0

# على Git Bash/MSYS يصل مسار POSIX إلى node.exe محرّفاً — نحوّله لصيغة Windows
if command -v cygpath >/dev/null 2>&1; then
  TMP_NODE="$(cygpath -m "$TMP")"
else
  TMP_NODE="$TMP"
fi

check() { # check <تسمية> <تعبير-node>
  local r
  r=$(node -e "
const s=JSON.parse(require('fs').readFileSync('$TMP_NODE','utf8'));
console.log(($2) ? 'PASS' : 'FAIL');
")
  if [ "$r" = "PASS" ]; then PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  ✗ %s\n' "$1"; node -e "console.log(JSON.stringify(JSON.parse(require('fs').readFileSync('$TMP_NODE','utf8')).permissions,null,1))"; fi
}

echo "=== حالة ١: مستخدم بـ allow ضيق ==="
cat > "$TMP" <<'EOF'
{"permissions":{"allow":["Read(*)","Grep(*)"],"defaultMode":"default"},"model":"sonnet"}
EOF
node "$REPO/install/merge-settings.js" --template "$TPL" --target "$TMP" --shell bash >/dev/null
check "allow بقي عنصرين"        "s.permissions.allow.length===2"
check "لا Bash(*) مُقحم"         "!s.permissions.allow.includes('Bash(*)')"
check "deny وصل (≥10 قاعدة)"     "Array.isArray(s.permissions.deny)&&s.permissions.deny.length>=10"

echo ""
echo "=== حالة ٢: مستخدم بـ permissions بلا allow (الثغرة السابقة) ==="
cat > "$TMP" <<'EOF'
{"permissions":{"defaultMode":"default"},"model":"sonnet"}
EOF
node "$REPO/install/merge-settings.js" --template "$TPL" --target "$TMP" --shell bash >/dev/null
check "allow فارغ لا مأخوذ من القالب" "Array.isArray(s.permissions.allow)&&s.permissions.allow.length===0"
check "deny وصل رغم ذلك"          "s.permissions.deny.length>=10"

echo ""
echo "=== حالة ٣: مستخدم بـ deny خاص ==="
cat > "$TMP" <<'EOF'
{"permissions":{"allow":["Read(*)"],"deny":["Bash(mycustom)"],"defaultMode":"default"}}
EOF
node "$REPO/install/merge-settings.js" --template "$TPL" --target "$TMP" --shell bash >/dev/null
check "deny الخاص محفوظ"          "s.permissions.deny.includes('Bash(mycustom)')"
check "deny القالب أُضيف"          "s.permissions.deny.some(d=>d.includes('rm -rf'))"

echo ""
echo "=== حالة ٤: مستخدم جديد بلا permissions ==="
cat > "$TMP" <<'EOF'
{"model":"sonnet"}
EOF
node "$REPO/install/merge-settings.js" --template "$TPL" --target "$TMP" --shell bash >/dev/null
check "يأخذ allow من القالب"       "s.permissions.allow.length>0"
check "لا Bash(*) في القالب"       "!s.permissions.allow.includes('Bash(*)')"
check "hooks تشمل PowerShell"      "JSON.stringify(s.hooks).includes('Bash|PowerShell')"

rm -f "$TMP"
echo ""
echo "========================================"
printf 'نجح: %s | فشل: %s\n' "$PASS" "$FAIL"
[ "$FAIL" = "0" ] && exit 0 || exit 1
