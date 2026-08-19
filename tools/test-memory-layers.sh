#!/usr/bin/env bash
# اختبار الذاكرة بطبقتين — يثبت الفصل بين العامة والمشروع
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$REPO/.mem-sandbox"
PROJ_A="$SANDBOX/proj-a"
PROJ_B="$SANDBOX/proj-b"
PASS=0; FAIL=0

topath() { command -v cygpath >/dev/null 2>&1 && cygpath -m "$1" || printf '%s' "$1"; }

ok()   { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  ✗ %s — %s\n' "$1" "${2:-}"; }

rm -rf "$SANDBOX" 2>/dev/null
mkdir -p "$SANDBOX/home" "$PROJ_A" "$PROJ_B"
export HOME_SANDBOX="$SANDBOX/home"

echo "=== تهيئة الطبقتين لمشروعين مختلفين ==="
( cd "$PROJ_A" && node "$REPO/install/init-memory.js" --claude-dir "$HOME_SANDBOX/.claude" >/dev/null )
( cd "$PROJ_B" && node "$REPO/install/init-memory.js" --claude-dir "$HOME_SANDBOX/.claude" >/dev/null )

ID_A=$(node -e "console.log(require('path').resolve(process.argv[1]).replace(/[\\\\/:]/g,'-'))" "$PROJ_A")
ID_B=$(node -e "console.log(require('path').resolve(process.argv[1]).replace(/[\\\\/:]/g,'-'))" "$PROJ_B")

[ -d "$HOME_SANDBOX/.claude/memory" ] && ok "الطبقة العامة أُنشئت" || bad "الطبقة العامة"
[ -d "$HOME_SANDBOX/.claude/projects/$ID_A/memory" ] && ok "طبقة المشروع أ أُنشئت" || bad "المشروع أ"
[ -d "$HOME_SANDBOX/.claude/projects/$ID_B/memory" ] && ok "طبقة المشروع ب أُنشئت" || bad "المشروع ب"
[ "$ID_A" != "$ID_B" ] && ok "المعرّفان مختلفان (لا خلط)" || bad "المعرّفان متطابقان"

echo ""
echo "=== كتابة ذكريات في كل طبقة ==="
cat > "$HOME_SANDBOX/.claude/memory/pref-global.md" <<'EOF'
---
name: pref-global
description: تفضيل عام يعبر المشاريع
metadata:
  type: user
---
تفضيل عام.
EOF
cat > "$HOME_SANDBOX/.claude/projects/$ID_A/memory/fact-a.md" <<'EOF'
---
name: fact-a
description: حقيقة تخص المشروع أ
metadata:
  type: project
---
حقيقة أ.
EOF
cat > "$HOME_SANDBOX/.claude/projects/$ID_B/memory/fact-b.md" <<'EOF'
---
name: fact-b
description: حقيقة تخص المشروع ب
metadata:
  type: project
---
حقيقة ب.
EOF

echo "=== مزامنة من داخل المشروع أ ==="
( cd "$PROJ_A" && HOME="$HOME_SANDBOX" USERPROFILE="$HOME_SANDBOX" node "$REPO/core/scripts/sync-memory.js" >/dev/null 2>&1 )

DB=$(topath "$HOME_SANDBOX/.claude/data/deepseek.db")
q() { node -e "
const {DatabaseSync}=require('node:sqlite');
const db=new DatabaseSync(process.argv[1],{readOnly:true});
try { console.log(db.prepare(process.argv[2]).get().c); } catch(e){ console.log('ERR'); }
db.close();" "$DB" "$1"; }

[ "$(q "SELECT COUNT(*) c FROM memories WHERE project IS NULL AND name='pref-global'")" = "1" ] \
  && ok "العام مخزَّن بـ project=NULL" || bad "العام" "لم يُخزَّن صحيحاً"
[ "$(q "SELECT COUNT(*) c FROM memories WHERE project IS NOT NULL AND name='fact-a'")" = "1" ] \
  && ok "حقيقة أ مخزَّنة بمعرّف المشروع" || bad "حقيقة أ"
[ "$(q "SELECT COUNT(*) c FROM memories WHERE name='fact-b'")" = "0" ] \
  && ok "حقيقة ب لم تتسرّب (لم يُزامَن مشروعها)" || bad "تسرّب" "ذاكرة مشروع آخر ظهرت"

echo ""
echo "=== مزامنة من داخل المشروع ب ==="
( cd "$PROJ_B" && HOME="$HOME_SANDBOX" USERPROFILE="$HOME_SANDBOX" node "$REPO/core/scripts/sync-memory.js" >/dev/null 2>&1 )
[ "$(q "SELECT COUNT(*) c FROM memories WHERE name='fact-b'")" = "1" ] \
  && ok "حقيقة ب ظهرت بعد مزامنة مشروعها" || bad "حقيقة ب"
[ "$(q "SELECT COUNT(*) c FROM memories WHERE name='fact-a'")" = "1" ] \
  && ok "حقيقة أ لم تُحذف عند مزامنة مشروع آخر" || bad "حقيقة أ" "حُذفت خطأً"
[ "$(q "SELECT COUNT(*) c FROM memories WHERE project IS NULL")" = "2" ] \
  && ok "الطبقة العامة سليمة (تفضيل + سجل هلوسات)" || bad "الطبقة العامة" "العدد غير متوقع"

echo ""
echo "=== سجل قديم بقيمة project موروثة يُصحَّح عند المزامنة ==="
# الخلل الواقعي: سجل سابق بقيمة project مختلفة كان يبقى بلا تحديث
# لأن UPDATE اشترط تطابق project — فتظهر الذاكرة في طبقة وهي مسجَّلة في أخرى
node -e "
const {DatabaseSync}=require('node:sqlite');
const db=new DatabaseSync(process.argv[1]);
db.prepare(\"UPDATE memories SET project='legacy-value' WHERE name='pref-global'\").run();
db.close();" "$DB"
[ "$(q "SELECT COUNT(*) c FROM memories WHERE name='pref-global' AND project='legacy-value'")" = "1" ] \
  && ok "هُيّئ سجل بقيمة موروثة" || bad "التهيئة"
( cd "$PROJ_A" && HOME="$HOME_SANDBOX" USERPROFILE="$HOME_SANDBOX" node "$REPO/core/scripts/sync-memory.js" >/dev/null 2>&1 )
[ "$(q "SELECT COUNT(*) c FROM memories WHERE name='pref-global' AND project IS NULL")" = "1" ] \
  && ok "الصف العام موجود بعد المزامنة" || bad "الصف العام" "غائب"
# الصف الموروث يبقى عمداً (لا حذف صامت لذاكرة قد تكون حيّة) لكن يجب
# أن يُبلَّغ عنه صراحة — الاختبار السابق لم يكن يرى وجوده أصلاً
[ "$(q "SELECT COUNT(*) c FROM memories WHERE name='pref-global' AND project='legacy-value'")" = "1" ] \
  && ok "الصف الموروث باقٍ (لا حذف صامت)" || bad "الصف الموروث" "حُذف بلا إذن"
( cd "$PROJ_A" && HOME="$HOME_SANDBOX" USERPROFILE="$HOME_SANDBOX" node "$REPO/core/scripts/sync-memory.js" 2>&1 | grep -q "صفوف بنطاق لا مجلد ذاكرة له" ) \
  && ok "المزامنة تُبلّغ عن الصفوف اليتيمة" || bad "الإبلاغ" "لا تحذير"
( cd "$PROJ_A" && HOME="$HOME_SANDBOX" USERPROFILE="$HOME_SANDBOX" node "$REPO/core/scripts/sync-memory.js" --prune-orphans >/dev/null 2>&1 )
[ "$(q "SELECT COUNT(*) c FROM memories WHERE project='legacy-value'")" = "0" ] \
  && ok "--prune-orphans يزيل النطاقات بلا مجلد" || bad "prune-orphans" "الصف اليتيم باقٍ"

echo ""
echo "=== عزل النطاق: اسم متكرر في مشروعين لا يتصادم ==="
# الثغرة: UPDATE بلا قيد نطاق كان يجعل مزامنة مشروع تستولي على سجل
# مشروع آخر يحمل نفس الاسم وتستبدل محتواه
cat > "$HOME_SANDBOX/.claude/projects/$ID_A/memory/notes.md" <<'EOF'
---
name: notes
description: ملاحظات المشروع أ
metadata:
  type: project
---
محتوى-أ-المميّز
EOF
cat > "$HOME_SANDBOX/.claude/projects/$ID_B/memory/notes.md" <<'EOF'
---
name: notes
description: ملاحظات المشروع ب
metadata:
  type: project
---
محتوى-ب-المميّز
EOF
( cd "$PROJ_A" && HOME="$HOME_SANDBOX" USERPROFILE="$HOME_SANDBOX" node "$REPO/core/scripts/sync-memory.js" >/dev/null 2>&1 )
( cd "$PROJ_B" && HOME="$HOME_SANDBOX" USERPROFILE="$HOME_SANDBOX" node "$REPO/core/scripts/sync-memory.js" >/dev/null 2>&1 )

[ "$(q "SELECT COUNT(*) c FROM memories WHERE name='notes'")" = "2" ] \
  && ok "سجلان منفصلان لنفس الاسم" || bad "العزل" "لم يُنشأ سجلان"
[ "$(q "SELECT COUNT(*) c FROM memories WHERE name='notes' AND content LIKE '%محتوى-أ-المميّز%'")" = "1" ] \
  && ok "محتوى المشروع أ سليم بعد مزامنة ب" || bad "تلاعب" "محتوى أ استُبدل"
[ "$(q "SELECT COUNT(*) c FROM memories WHERE name='notes' AND content LIKE '%محتوى-ب-المميّز%'")" = "1" ] \
  && ok "محتوى المشروع ب مخزَّن بشكل مستقل" || bad "محتوى ب"

rm -rf "$SANDBOX"
echo ""
echo "========================================"
printf 'نجح: %s | فشل: %s\n' "$PASS" "$FAIL"
[ "$FAIL" = "0" ] && exit 0 || exit 1
