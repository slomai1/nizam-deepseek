#!/usr/bin/env bash
# ============================================================
# check-model-names.sh — فحص توفر أسماء النماذج عند بوابة DeepSeek
#
# لماذا: فتحة sonnet مضبوطة على اسم تجريبي (deepseek-v4-flash-vision-exp)
# قد يغيّره المزود دون إنذار، فتتعطل البوابة بلا سبب واضح. هذا الفحص
# يقارن أسماء النماذج المضبوطة في القالب مع قائمة النماذج الفعلية،
# ويعطي رسالة موجّهة تحيل إلى docs/03 عند تغيّر الاسم.
#
# الاستخدام:
#   bash check-model-names.sh [--template <path>] [--base-url <url>] [--strict]
#
# السلوك:
#   • بلا ANTHROPIC_AUTH_TOKEN أو بلا شبكة: تحذير وتخطٍّ (exit 0) — الفحص
#     استشاري عند التركيب ولا يمنع تركيباً بلا مفتاح
#   • --strict: exit 1 إذا وُجد اسم مفقود وقد وصلنا فعلاً إلى قائمة النماذج
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$REPO_DIR/templates/settings.template.json"
BASE_URL="${DEEPSEEK_API_BASE:-https://api.deepseek.com}"
STRICT=0

usage() {
  sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --template) TEMPLATE="$2"; shift 2 ;;
    --base-url)  BASE_URL="$2"; shift 2 ;;
    --strict)    STRICT=1; shift ;;
    -h|--help)   usage ;;
    *) printf 'خيار غير معروف: %s (جرّب --help)\n' "$1" >&2; exit 2 ;;
  esac
done

command -v node >/dev/null 2>&1 || { printf '✗ node غير موجود — لا يمكن قراءة القالب\n' >&2; exit 2; }
command -v curl >/dev/null 2>&1 || { printf '✗ curl غير موجود — لا يمكن فحص البوابة\n' >&2; exit 2; }

# أسماء النماذج من قالب الإعدادات — المسار يُمرَّر كوسيط (process.argv)
# لا يُدرج داخل الكود، وإلا أمكن لمسار خبيث حقن JavaScript
MODELS_JSON="$(node -e '
const fs = require("fs");
const s = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const e = s.env || {};
console.log(JSON.stringify({
  opus:   e.ANTHROPIC_DEFAULT_OPUS_MODEL   || "",
  sonnet: e.ANTHROPIC_DEFAULT_SONNET_MODEL || "",
  haiku:  e.ANTHROPIC_DEFAULT_HAIKU_MODEL  || ""
}));
' "$TEMPLATE")" || { printf '✗ تعذّر قراءة القالب: %s\n' "$TEMPLATE" >&2; exit 2; }

TOKEN="${ANTHROPIC_AUTH_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  printf '⚠ لم نجد ANTHROPIC_AUTH_TOKEN في البيئة — تخطّي فحص توفر أسماء النماذج.\n'
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! curl -sS -m 10 -o "$TMP" -H "Authorization: Bearer $TOKEN" "$BASE_URL/models" 2>/dev/null; then
  printf '⚠ تعذّر الوصول إلى %s/models — تخطّي فحص الأسماء (لا شبكة؟).\n' "$BASE_URL"
  exit 0
fi

# المقارنة: لاحقة [1m] لا تظهر عادةً في قائمة النماذج — نقارن بالاسم الأساسي
RESULT="$(node -e '
const fs = require("fs");
let body;
try { body = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
catch (e) { process.exit(3); }
const ids = new Set((body.data || body.models || [])
  .map((m) => String(m.id || m.name || "").replace(/\[1m\]$/, "")));
const configured = JSON.parse(process.argv[2]);
let missing = 0;
for (const [slot, name] of Object.entries(configured)) {
  const base = String(name).replace(/\[1m\]$/, "");
  if (!base) continue;
  if (ids.has(base)) {
    console.log("OK|" + slot + "|" + name);
  } else {
    missing++;
    console.log("MISSING|" + slot + "|" + name);
  }
}
process.exitCode = missing > 0 ? 1 : 0;
' "$TMP" "$MODELS_JSON")"
PARSE_CODE=$?

if [ "$PARSE_CODE" = "3" ] || [ -z "$RESULT" ]; then
  printf '⚠ تعذّر تحليل استجابة البوابة (مفتاح غير صالح أو صيغة غير متوقعة) — تخطّي الفحص.\n'
  exit 0
fi

MISSING=0
while IFS='|' read -r status slot name; do
  [ -n "$status" ] || continue
  if [ "$status" = "OK" ]; then
    printf '✓ %s: %s متوفر عند البوابة\n' "$slot" "$name"
  else
    MISSING=$((MISSING + 1))
    printf '✗ %s: %s غير موجود في قائمة النماذج\n' "$slot" "$name" >&2
    printf '  قد يكون المزود غيّر الاسم التجريبي. راجع docs/03-الأخطاء-الشائعة.md (البند ١)\n' >&2
    printf '  ثم حدّث الاسم في templates/settings.template.json ولوّن قائمة النماذج عند: %s/models\n' "$BASE_URL" >&2
  fi
done <<< "$RESULT"

if [ "$MISSING" -gt 0 ] && [ "$STRICT" = "1" ]; then
  printf '✗ %s اسم نموذج مفقود (--strict)\n' "$MISSING" >&2
  exit 1
fi

if [ "$MISSING" -gt 0 ]; then
  printf '⚠ %s اسم مفقود — الفحص استشاري هنا؛ مرّر --strict لتفشيله\n' "$MISSING"
fi
exit 0
