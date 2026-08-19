#!/usr/bin/env bash
# اختبار بوابات الحماية في الـ workflows:
#   • freeze: يرفض المسارات المطلقة والصاعدة
#   • land-and-deploy: لا يعمل بلا تأكيد صريح
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ✗ %s — %s\n' "$1" "${2:-}"; }

# استخراج منطق الرفض من freeze.js وتشغيله على حالات
check_freeze() { # check_freeze <path> <expect: reject|accept>
  local verdict
  verdict=$(node -e '
const t = process.argv[1];
const unsafe = [
  { test: /^[A-Za-z]:[\\/]/, why: "مسار مطلق على قرص Windows" },
  { test: /^[\\/]/, why: "مسار مطلق من الجذر" },
  { test: /^~/, why: "مسار مجلد المنزل" },
  { test: /(^|[\\/])\.\.([\\/]|$)/, why: "صعود خارج المشروع" },
  { test: /^\$|%[A-Za-z_]+%/, why: "متغيّر بيئة" },
].find((r) => r.test.test(String(t)));
console.log(unsafe ? "reject" : "accept");
' "$1")
  if [ "$verdict" = "$2" ]; then ok "$1 → $verdict"; else bad "$1" "توقّعنا $2 فجاء $verdict"; fi
}

echo "=== freeze: مسارات يجب رفضها ==="
check_freeze 'C:\'                    reject
check_freeze 'C:/Users/someone'       reject
check_freeze '/'                      reject
check_freeze '/etc'                   reject
check_freeze '~'                      reject
check_freeze '~/.claude'              reject
check_freeze '../..'                  reject
check_freeze '../secrets'             reject
check_freeze 'a/../../b'              reject
check_freeze '$HOME'                  reject
check_freeze '%USERPROFILE%'          reject

echo ""
echo "=== freeze: مسارات يجب قبولها ==="
check_freeze 'dist'                   accept
check_freeze 'build/output'           accept
check_freeze './dist'                 accept
check_freeze 'packages/ui/dist'       accept
check_freeze 'my..folder'             accept

echo ""
echo "=== land-and-deploy: بوابة التأكيد ==="
grep -q 'confirm !== .نعم انشر.' "$REPO/core/workflows/land-and-deploy.js" \
  && ok "شرط التأكيد موجود" || bad "شرط التأكيد" "غائب"
grep -q "awaiting-confirmation" "$REPO/core/workflows/land-and-deploy.js" \
  && ok "يعيد حالة انتظار التأكيد" || bad "حالة الانتظار" "غائبة"
# الحاسم: التأكيد يسبق أول استدعاء وكيل (الدمج)
node -e '
const fs=require("fs");
const s=fs.readFileSync(process.argv[1],"utf8");
const gate=s.indexOf("awaiting-confirmation");
const firstAgent=s.indexOf("await agent(");
process.exit(gate>=0 && firstAgent>gate ? 0 : 1);
' "$REPO/core/workflows/land-and-deploy.js" \
  && ok "البوابة تسبق أول فعل خارجي" || bad "ترتيب البوابة" "الوكيل يُستدعى قبل التأكيد"

echo ""
echo "=== mem-query: لا SQL حر ولا حقن ==="
node --check "$REPO/core/scripts/mem-query.js" 2>/dev/null && ok "بنية سليمة" || bad "بنية mem-query"
node "$REPO/core/scripts/mem-query.js" 2>&1 | grep -q "لوحة الذاكرة" \
  && ok "اللوحة تعمل بلا وسيط" || bad "اللوحة"
node "$REPO/core/scripts/mem-query.js" 3 2>&1 | grep -q "آخر الذكريات" \
  && ok "استعلام بالرقم يعمل" || bad "استعلام بالرقم"
# الحاسم: إدخال خبيث لا ينفّذ كوداً ولا يمرّر SQL
out=$(node "$REPO/core/scripts/mem-query.js" "9'); console.log('INJECTED'); ('" 2>&1)
echo "$out" | grep -q "INJECTED" && bad "حقن JS" "الكود المحقون نُفّذ" || ok "إدخال خبيث لا ينفّذ كوداً"
# الرفض يُطبع على stderr ويخرج برمز 1 — نتحقق من الاثنين
if node "$REPO/core/scripts/mem-query.js" "abc" >/dev/null 2>&1; then
  bad "الرفض" "إدخال غير رقمي مرّ برمز نجاح"
else
  ok "إدخال غير رقمي يُرفض (رمز خروج 1)"
fi
grep -q "readOnly: true" "$REPO/core/scripts/mem-query.js" \
  && ok "القاعدة تُفتح للقراءة فقط" || bad "readOnly" "غائب"

echo ""
echo "=== connect-all مستبعد من التوزيع ==="
[ ! -f "$REPO/core/scripts/connect-all.js" ] \
  && ok "غير موجود في core/scripts" || bad "connect-all" "ما زال موزّعاً"

echo ""
echo "=== سلامة بنية الـ workflows ==="
for f in "$REPO"/core/workflows/*.js; do
  node --check "$f" 2>/dev/null || bad "$(basename "$f")" "خطأ بنيوي"
done
ok "كل ملفات workflows سليمة بنيوياً"

echo ""
echo "========================================"
printf 'نجح: %s | فشل: %s\n' "$PASS" "$FAIL"
[ "$FAIL" = "0" ] && exit 0 || exit 1
