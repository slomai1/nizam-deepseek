#!/usr/bin/env bash
# ============================================================
# اختبارات سلوكية لـ sprint وauto-verify (تنفيذ القضية #2)
#
# الفرق عن فحص 3818def البنيوي: هذه الاختبارات تُنفّذ منطق الملفات
# نفسها — لا نسخة من خريطتها داخل الاختبار — وتتحقق من المراحل
# الفعلية التي تعمل، وجهد المراجعة الفعلي، ومصفوفة أفعال التصحيح الخمسة.
#
# الاستخدام: bash tools/test-sprint-autoverify.sh
# ============================================================
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ✓ %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  ✗ %s — %s\n' "$1" "${2:-}"; }

# مشغّل: يُنفّذ ملف workflow ببدائل أدوات مسجِّلة، ثم يطبع سجل النداءات JSON
run_workflow() { # run_workflow <ملف> <args-JSON>
  node -e '
const fs = require("fs");
const src = fs.readFileSync(process.argv[1], "utf8").replace(/^export\s/mg, "");
const argsIn = JSON.parse(process.argv[2]);
const rec = { phases: [], logs: [], agents: [], workflows: [] };
const log = (...a) => rec.logs.push(a.map(String).join(" "));
const phase = (t) => { rec.phases.push(String(t)); };
const agent = async (prompt, opts = {}) => {
  rec.agents.push({ label: opts.label || "", prompt: String(prompt), agentType: opts.agentType || null });
  return "نتيجة:" + (opts.label || "");
};
const workflow = async (name, wargs) => {
  rec.workflows.push({ name: String(name), effort: wargs && wargs.effort });
  return "نتيجة-workflow:" + name;
};
const parallel = async (fns) => Promise.all(fns.map((f) => f()));
const fn = new Function("args", "log", "phase", "agent", "workflow", "parallel",
  "return (async () => {" + src + "})()");
fn(argsIn, log, phase, agent, workflow, parallel)
  .then(() => console.log(JSON.stringify(rec)))
  .catch((e) => { console.error("EXEC-FAIL: " + e.message); process.exit(9); });
' "$1" "$2"
}

echo "=== sprint: المراحل الفعلية حسب حجم المهمة ==="

SPRINT="$REPO/core/workflows/sprint.js"

check_sprint() { # check_sprint <size> <مراحل متوقعة مفصولة بفاصلة> <جهد المراجعة المتوقع>
  local size="$1" expected="$2" effort="$3"
  local out phases wfs
  out="$(run_workflow "$SPRINT" "{\"task\":\"مهمة تجريبية\",\"size\":\"$size\"}")" \
    || { bad "sprint/$size" "فشل تنفيذ الملف"; return; }
  phases="$(printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).phases.join(",")))')"
  wfs="$(printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.stringify(JSON.parse(s).workflows)))')"
  if [ "$phases" = "$expected" ]; then
    ok "sprint/$size: المراحل = [$phases]"
  else
    bad "sprint/$size" "المراحل [$phases] ≠ المتوقع [$expected]"
  fi
  if printf '%s' "$wfs" | grep -q "{\"name\":\"deep-review\",\"effort\":\"$effort\"}"; then
    ok "sprint/$size: deep-review بجهد $effort"
  else
    bad "sprint/$size" "deep-review لم يُستدع بجهد $effort — $wfs"
  fi
}

check_sprint "small"     "بناء,مراجعة"                    "medium"
check_sprint "medium"    "مواصفات,تخطيط,بناء,مراجعة"      "high"
check_sprint "large"     "مواصفات,تخطيط,بناء,مراجعة,تدقيق" "high"
check_sprint "sensitive" "مواصفات,تخطيط,بناء,مراجعة,تدقيق,شحن" "max"

echo ""
echo "=== sprint: احتياطي الحجم المجهول وسلوك المدخلات ==="

out="$(run_workflow "$SPRINT" '{"task":"مهمة","size":"giant"}')" \
  && phases="$(printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).phases.join(",")))')" \
  && [ "$phases" = "مواصفات,تخطيط,بناء,مراجعة" ] \
  && ok "حجم مجهول (giant) → مسار medium" \
  || bad "sprint/giant" "لا احتياطي للمجهول"

out="$(run_workflow "$SPRINT" 'null')" \
  && printf '%s' "$out" | grep -q "لا توجد مهمة محددة" \
  && ok "بلا مهمة: يطبع التحذير ولا يسقط" \
  || bad "sprint/بلا-مهمة" "التحذير غائب"

out="$(run_workflow "$SPRINT" '{"task":"مهمة","size":"large"}')" \
  && printf '%s' "$out" | grep -q '"name":"auto-verify"' \
  && ok "large/sensitive تشغّل auto-verify للتدقيق" \
  || bad "sprint/large" "auto-verify لم يُستدع للتدقيق"

out="$(run_workflow "$SPRINT" '{"task":"مهمة","size":"small"}')" \
  && printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s);process.exit(r.workflows.some(w=>w.name==="auto-verify")?1:0)})' \
  && ok "small لا تشغّل auto-verify (بلا تدقيق)" \
  || bad "sprint/small" "auto-verify استُدعي خطأً"

echo ""
echo "=== auto-verify: المراحل ومصفوفة الأفعال الخمسة ==="

AV="$REPO/core/workflows/auto-verify.js"

out="$(run_workflow "$AV" '"src/api"')" \
  || bad "auto-verify" "فشل تنفيذ الملف"

if [ -n "${out:-}" ]; then
  phases="$(printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).phases.join(",")))')"
  [ "$phases" = "اكتشاف,اختبار,تصحيح,تقرير" ] \
    && ok "المراحل: اكتشاف → اختبار → تصحيح → تقرير" \
    || bad "auto-verify/المراحل" "[$phases]"

  fix_prompt="$(printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s);const a=r.agents.find(x=>x.label==="تصحيح ذاتي");console.log(a?a.prompt:"")})')"

  FIVE_OK=1
  for v in "موثوق" "قابل للتشخيص" "تعارض مسارات" "لا قيد جديد" "انحلال"; do
    printf '%s' "$fix_prompt" | grep -q "$v" || { FIVE_OK=0; bad "auto-verify/الأفعال" "الفعل «$v» غائب من برومبت التصحيح"; }
  done
  [ "$FIVE_OK" = "1" ] && ok "مصفوفة الأفعال الخمسة كاملة في التصحيح"

  printf '%s' "$fix_prompt" | grep -q "🛑 يحتاج تدخل بشري" \
    && ok "قاعدة التوقف بعد 3 محاولات موجودة" \
    || bad "auto-verify/التوقف" "قاعدة التوقف غائبة"

  printf '%s' "$fix_prompt" | grep -q "لا تعدل ملفات غير متعلقة بالخطأ" \
    && ok "قصر التعديل على نطاق الخطأ" \
    || bad "auto-verify/النطاق" "قيد النطاق غائب"

  disc_prompt="$(printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s);const a=r.agents.find(x=>x.label==="اكتشاف التغييرات");console.log(a?a.prompt:"")})')"
  printf '%s' "$disc_prompt" | grep -q "src/api" \
    && ok "الهدف الممرر كنص يصل إلى مرحلة الاكتشاف" \
    || bad "auto-verify/الهدف" "الهدف لم يصل"

  if printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s);process.exit(r.agents.length===3?0:1)})'; then
    ok "3 وكلاء (اكتشاف · اختبار · تصحيح) والتقرير محلي"
  else
    bad "auto-verify/الوكلاء" "عدد الوكلاء غير متوقع"
  fi
fi

echo ""
echo "========================================"
printf 'نجح: %s | فشل: %s\n' "$PASS" "$FAIL"
[ "$FAIL" = "0" ] && exit 0 || exit 1
