# إشعار النسبة والأعمال المشتقة

> هذا المستودع يحوي الأعمال الأصلية للمؤلف، **إضافةً إلى ٣ مهارات من طرف ثالث بِترخيص MIT** (تُوزَّع هنا مع نماذج رخصها). أما بقية المكوّنات من طرف ثالث فتُجلب من مصادرها عند التركيب ولا تُوزَّع هنا.

## عمل المؤلف الأصلي

| المكوّن                   | الوصف                                                                                                                  |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `rules/`                  | سياسة التشغيل (١٦ قسماً) + Golden Set — نظام حوكمة كامل                                                                |
| `hooks/`                  | ٥ خطافات حماية (منع أوامر خطرة، كشف أسرار، مكافحة هلوسة مسارات، منع حلقات، تنسيق)                                      |
| `commands/`               | ٢٤ أمر سلاش عربياً                                                                                                     |
| `workflows/`              | ١٠ خطوط جودة أصلية                                                                                                     |
| `skills/`                 | ٧ مهارات عربية (design-pipeline، checklist-ui، arabic-design، auto-build، debugging-wizard، feature-forge، spec-miner) |
| `install/` · `templates/` | سكربتا تركيب + قوالب إعدادات ومخطط قاعدة الذاكرة                                                                       |
| `docs/`                   | التوثيق العربي، من ضمنه تجربة تركيب DeepSeek الموثقة                                                                   |

## أعمال استُبعدت عمداً (تأتي من مصادرها)

هذه المكوّنات كانت في نظام المؤلف الشخصي لكنها **ليست من تأليفه**، لذلك لا تُنسخ هنا ويجلبها سكربت التركيب من مصادرها الأصلية عبر آلية الملحقات:

| المكوّن                                                            | المصدر الأصلي                                                                                                                   |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| وكلاء VoltAgent (بما فيها النسخ المعرّبة الأربعة)                  | [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)                           |
| مهارات WordPress                                                   | [Automattic/wordpress-agent-skills](https://github.com/Automattic/wordpress-agent-skills)                                       |
| مهارات Flutter/Dart                                                | [VeryGoodOpenSource/very-good-claude-code-marketplace](https://github.com/VeryGoodOpenSource/very-good-claude-code-marketplace) |
| `pdf` · `xlsx` · `skill-development`                               | [anthropics/skills](https://github.com/anthropics/skills) — © 2025 Anthropic, PBC                                               |
| مجموعة agent-skills                                                | [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)                                                           |
| مهارة `impeccable`                                                 | منظومة Anthropic/Codex — أصلية من بيئة خارجية                                                                                   |
| مهارة `git-cleanup`                                                | منظمة Trail of Bits (دليل: شعار ToB + agents/openai.yaml)                                                                       |
| ١٤ سوقاً للملحقات                                                  | القائمة الكاملة في [`docs/05-الملحقات-والمصادر.md`](docs/05-الملحقات-والمصادر.md)                                               |

## أعمال مُوزَّعة هنا بِترخيص MIT

ثلاث مهارات من طرف ثالث رُخّصت بـ MIT، فيُسمح بإعادة توزيعها مع إبقاء حقوق النشر وملاحظة الرخصة — وهي مضمّنة في `core/skills/` بنماذج رخصها الأصلية:

| المهارة                  | صاحب الحقوق          | مجلد الرخصة                          |
| ------------------------ | --------------------- | ------------------------------------ |
| `code-review-skill`      | tt-a1i                | `core/skills/code-review-skill/LICENSE`      |
| `humanizer`              | Siqi Chen             | `core/skills/humanizer/LICENSE`              |
| `motion-dev-animations`  | 199 Biotechnologies   | `core/skills/motion-dev-animations/LICENSE`  |

> تُقدَّم هذه المهارات كما هي دون أي تعديل، وتبقى خاضعة لترخيص MIT الأصلي — لا يشمله ترخيص هذا المستودع (MIT للمؤلف الأصلي) إلا في نطاقها الخاص.

## أسئلة حقوق النشر

المكوّنات المستوردة تحتفظ بتراخيصها الأصلية كما هي في مستودعاتها. لا يُطبَّق ترخيص MIT لهذا المستودع إلا على الأعمال الأصلية للمؤلف الموضحة في الجدول الأول.
