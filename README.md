# نِظام DeepSeek × Claude Code

> Official DeepSeek + Claude Code setup is two env vars. One wrong `claude-*` model name, or a leftover `ANTHROPIC_MODEL`, and `/model` dies or the gateway returns 400.
>
> This repo is the rest of that setup: Flash/Pro slots that actually switch, hooks that fail closed, and an installer that will not overwrite your files unless you pass `--force`.
>
> `./install/install.sh` for the full core. `./install/install.sh --minimal` if you only want the reviewed nucleus — no third-party marketplaces.

نظام تشغيل كامل فوق Claude Code يعمل بنماذج **DeepSeek** عبر بوابة متوافقة مع Anthropic — سياسات حوكمة، خطافات حماية، أوامر عربية، خطوط جودة، ونظام ذاكرة — كله موثّق بالعربية ومُختبر على أرض الواقع.

> **الغرض:** مرجعٌ لمن يريد تركيب DeepSeek داخل Claude Code، مع نظام كامل جاهز لا يحتاج التجميع بنفسه.

---

## لماذا هذا المستودع؟

تشغيل DeepSeek داخل Claude Code **أصعب مما يبدو** — وهذه المعرفة مبعثرة ومكلفة:

- اسم نموذج خاطئ واحد (`claude-*` بدل `deepseek-*`) يعطّل البوابة بالكامل
- `env.ANTHROPIC_MODEL` يثبّت النموذج ويلغي التبديل عبر `/model`
- عيوب تكامل موثقة تظهر وتختفي بين إصدارات Claude Code
- الفتحات (`opus`/`sonnet`/`haiku`) لا تعكس النموذج الفعلي

هذا المستودع يوثّق ما تعلّمناه بالاختبار (مع شرط قياس كل نتيجة)، ويركّب نظاماً كاملاً فوقها.

## التركيب

### المتطلبات

| المتطلب        | الحد الأدنى                                           |
| -------------- | ----------------------------------------------------- |
| Claude Code    | أحدث نسخة (≥ 2.1.233 — عيوب التكامل القديمة زالت هنا) |
| Node.js        | ≥ 22.5 (لأجل `node:sqlite`)                           |
| bash           | على Windows: Git Bash أو WSL                          |
| مفتاح DeepSeek | من منصة DeepSeek                                      |

### ٣ خطوات

```bash
# ١. استنسخ المستودع
git clone https://github.com/slomai1/nizam-deepseek.git
cd nizam-deepseek

# ٢. شغّل التركيب
./install/install.sh              # macOS/Linux/Git Bash
# أو على Windows:
# .\install\install.ps1

# ٣. عيّن مفتاح DeepSeek
export ANTHROPIC_AUTH_TOKEN="sk-..."
```

ثم شغّل `claude`. عند أول تشغيل تُجلب الملحقات (١٨ ملحقاً من ١٤ سوقاً) تلقائياً، وستجد النظام جاهزاً.

### خيارات التركيب

| العلم | الأثر |
|---|---|
| _(بلا علم)_ | **لا يستبدل ملفاتك الموجودة** — يضيف الناقص فقط ويخبرك بما تخطّاه |
| `--force` | يستبدل الملفات الموجودة بنسخة المستودع |
| `--minimal` | النواة فقط: خطافات وقواعد وأوامر وذاكرة — **بلا أي ملحق أو سوق** |
| `--dry-run` | يعرض ما سيحدث دون تنفيذ |

على PowerShell: `-Force` · `-Minimal` · `-DryRun`.

> التركيب المتكرر آمن: عدّل خطافاً أو `CLAUDE.md` كما تشاء، وإعادة التركيب لن تدهس تعديلك ما لم تطلب `--force` صراحةً.

> **جرّب فوراً:** `/model opus` ثم `/model sonnet` — إن عملا، البوابة سليمة و`ANTHROPIC_MODEL` غير مثبّت.

## ماذا تحصل عليه؟

| الطبقة          | المحتوى                                                                               |
| --------------- | ------------------------------------------------------------------------------------- |
| الحوكمة         | `rules/` — سياسة تشغيل من ١٦ قسماً + Golden Set                                       |
| الحماية         | `hooks/` — ٥ خطافات: منع أوامر خطرة، كشف أسرار، مكافحة هلوسة مسارات، منع حلقات، تنسيق |
| القواعد اليومية | `CLAUDE.md` — تُقرأ كل جلسة                                                           |
| الأوامر         | `commands/` — ٢٢ أمراً عربياً                                                         |
| خطوط الجودة     | `workflows/` — ١٠ خطوط (quick-check، deep-review، sprint، canary...)                  |
| المهارات        | `skills/` — ٢٠ مهارة (١٧ أصلية + ٣ خارجية مرخّصة MIT)                                  |
| الذاكرة         | نظام كامل: أوامر + مخطط SQLite + سكربت مزامنة                                         |

## التوثيق

| الملف                                                  | المحتوى                                            |
| ------------------------------------------------------ | -------------------------------------------------- |
| [٠١ — تركيب DeepSeek](docs/01-تركيب-deepseek.md)       | **قلب المرجع** — البوابة، المزالق، العيوب، المعيار |
| [٠٢ — توجيه النماذج](docs/02-توجيه-النماذج.md)         | Flash أم Pro؟ ومبدأ التصعيد                        |
| [٠٣ — الأخطاء الشائعة](docs/03-الأخطاء-الشائعة.md)     | ٨ مزالق موثقة بالحلول                              |
| [٠٤ — بنية النظام](docs/04-بنية-النظام.md)             | كيف تتركب الطبقات السبع                            |
| [٠٥ — الملحقات والمصادر](docs/05-الملحقات-والمصادر.md) | ما يُجلب من أين                                    |
| [٠٦ — المرجع الشامل](docs/06-المرجع-الشامل.md)         | كل شيء: الطبقات السبع + ٢٢ أمراً + ١٠ خطوط جودة + ٢٠ مهارة |
| [٠٧ — المهارات الشخصية ومصادرها](docs/07-المهارات-الشخصية-مصادرها.md) | مصفوفة مصادِر مهارات ~/.claude/skills/ — ما يُثبَّت من مصدر وما يُمرَّر مباشرةً |

## معاينة إعدادات النماذج

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-flash-vision-exp",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash[1m]",
    "CLAUDE_CODE_EFFORT_LEVEL": "high"
  }
}
```

## الأمان

- **لا أسرار في المستودع**: مفاتيحك تُمرَّر عبر متغير بيئة، وليست في أي ملف داخل هذا المستودع.
- **بوابة فحص ما قبل النشر**: `./tools/pre-publish-check.sh` يفحص أنماط الأسرار قبل كل دفع.
- **خطافات حماية**: ٥ خطافات تمنع الأوامر المدمِّرة، وتكشف الأسرار، وتوقف هلوسة المسارات، وتمنع الحلقات اللانهائية.
- **٣٢ قاعدة `deny`**: تشمل حماية ملفات النظام نفسها — الوكيل لا يستطيع تعديل الخطافات أو `settings.json` أو قراءة `~/.ssh` و`.credentials.json`.
- **تأكيد إلزامي للنشر**: `land-and-deploy` يدمج PR وينشر للإنتاج، فلا يعمل إلا بتمرير `confirm: "نعم انشر"` صراحةً في نفس الاستدعاء.

> **أثر مقصود:** حماية الخطافات و`settings.json` تعني أن **الوكيل لن يعدّلها حتى حين تطلب منه ذلك** — بما فيه صيانتها. عدّلها بنفسك، أو أزل القاعدة مؤقتاً وأعدها. هذا هو الغرض: ألا يملك النظام سلطة تعطيل حمايته.

### الاختبارات

١٠١ حالة تعمل عند كل دفع عبر CI:

```bash
bash tools/test-hooks.sh           # ٢٩ حالة — منع/سماح + fail-closed
bash tools/test-merge.sh           # ١٠ حالات — الدمج لا يوسّع الصلاحيات
bash tools/test-memory-layers.sh   # ١٨ حالة — عزل الذاكرة بين المشاريع
bash tools/test-workflow-guards.sh # ٢٩ حالة — بوابات النشر والمسارات
bash tools/test-install.sh         # ١٥ حالة — دهس · force · minimal
bash tools/pre-publish-check.sh    # بوابة الأسرار
```

## الترخيص والنسبة

- كود هذا المستودع الأصلي: **MIT** — راجع [LICENSE](LICENSE)
- الأعمال المستوردة من طرف ثالث تبقى في مصادرها ولا تُوزَّع هنا — **باستثناء ٣ مهارات MIT** (code-review-skill · humanizer · motion-dev-animations) مضمّنة مع رخصها — التفاصيل في [NOTICE](NOTICE.md)
