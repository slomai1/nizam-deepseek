# ١ — تركيب DeepSeek داخل Claude Code

> هذا الملف هو جوهر المستودع: خلاصة تجربة موثقة في تشغيل نماذج DeepSeek داخل Claude Code عبر بوابة متوافقة مع Anthropic. كل رقم مذكور هنا يُقرأ مع شرط قياسه (النسخة، التاريخ، عدد الحالات).

## البوابة

Claude Code يتصل بـ Anthropic عبر نقطة نهاية متوافقة. لتشغيله على DeepSeek، وجّه نقطة النهاية إلى بوابة DeepSeek:

| الإعداد              | القيمة                                           |
| -------------------- | ------------------------------------------------ |
| `ANTHROPIC_BASE_URL` | `https://api.deepseek.com/anthropic`             |
| التوكن               | `ANTHROPIC_AUTH_TOKEN` — مفتاح DeepSeek الخاص بك |

في `settings.json`:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic"
  }
}
```

التوكن يُمرَّر عبر متغير بيئة `ANTHROPIC_AUTH_TOKEN`، أو يُخزَّن مشفّراً في `.auth.sec` عند تسجيل الدخول عبر `claude` — وليس في `settings.json` (الذي لا يحوي أي سر).

## المزلق الأول — أسماء النماذج

**استخدم فقط أسماء `deepseek-*`:**

```json
{
  "env": {
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-flash[1m]",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash[1m]"
  }
}
```

لماذا؟ أي اسم `claude-*` (مثل `claude-opus-5`) يجعل Claude Code يعامله كنموذج Anthropic أصيل، فيرسل ميزات ورؤوس beta خاصة ترفضها بوابة DeepSeek فيتعطّل الطلب. **رغم** أن ترجمة DeepSeek الرسمية تقبل البادئة، الاستخدام المباشر لـ `claude-*` يكسر البوابة.

التحذير `[claude-code:unrecognized_model]` في وضع `-p`/SDK **غير ضار** — تجاهله ولا تعالجه بتغيير اسم النموذج.

## لا تضع `env.ANTHROPIC_MODEL`

وجود `ANTHROPIC_MODEL` يثبّت نموذجاً واحداً ويلغي التبديل عبر `/model`. حذفه هو ما يمنحك حرية التبديل بين Flash وPro أثناء الجلسة.

## خريطة الفتحات

| فتحة `/model` | النموذج الفعلي          |
| ------------- | ----------------------- |
| `opus`        | `deepseek-v4-pro[1m]`   |
| `sonnet`      | `deepseek-v4-flash[1m]` |
| `haiku`       | `deepseek-v4-flash[1m]` |

أسماء الفتحات توافقية مع واجهة Anthropic ولا تعكس النموذج الفعلي.

## `CLAUDE_CODE_EFFORT_LEVEL`

التفكير الفعلي على DeepSeek يعمل بقيمتي `high`/`max` فقط؛ القيم الأخرى خرائط توافقية بلا عمق حقيقي. الإعداد المستخدم:

```
CLAUDE_CODE_EFFORT_LEVEL=high
```

## عيوب تكامل موثقة — ومرجع دفاعي

ثلاثة عيوب توثّقها المجتمع (GitHub issues) بين DeepSeek V4 وClaude Code، ظهرت على نسخة **2.1.166**، وتحققنا من **زوالها على 2.1.233** (اختبار وكيل فرعي فعلي + WebSearch + WebFetch):

| العيب                                                                                | الظهور  | الرابط                                                                                                                                                 |
| ------------------------------------------------------------------------------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| تعارض `thinking:disabled` + `reasoning_effort` — يكسر الوكلاء الفرعيين بـ 400        | 2.1.166 | [issue #1397](https://github.com/deepseek-ai/DeepSeek-V3/issues/1397) · [issue #193](https://github.com/deepseek-ai/awesome-deepseek-agent/issues/193) |
| تجميد مصنّف أمان Bash — أول بايت يأخذ زمن التفكير كاملاً (28–32 ث) فيتجاوز مهلة 30 ث | 2.1.166 | [issue #1464](https://github.com/deepseek-ai/DeepSeek-V3/issues/1464)                                                                                  |
| رفض `tool_choice` — يعطّل WebSearch/WebFetch                                         | 2.1.166 | [issue #606](https://github.com/deepseek-ai/awesome-deepseek-integration/issues/606)                                                                   |

**إصلاحات المجتمع إن رجعت الأعراض عند تخفيض النسخة:** `dsv4-subagent-fix` (يزيل `output_config` من طلبات subagents)، `dsv4-cc-proxy`، أو تعطيل thinking على استدعاء المصنّف.

## MCP عبر البوابة

بعض خوادم MCP تحتاج اتصالات خارجية مباشرة لا تمر عبر البوابة. عند فشلها: لا تتوقف — انتقل إلى البديل المحلي (CLI أو WebFetch)، ثم سجّل نمط الفشل.

## معيار Flash مقابل Pro

قياس موثق (2026-08-17): ٥ مهام × نموذجين بوكلاء فرعيين معزولين.

| المهمة              | النتيجة                             |
| ------------------- | ----------------------------------- |
| ترجمة               | Flash يكافئ Pro                     |
| قواعد RLS           | Flash يكافئ Pro                     |
| RTL                 | Flash يكافئ Pro                     |
| قاعدة بيانات        | Flash يكافئ Pro                     |
| كشف الفرضية الكاذبة | **Pro فاز** — رفض اختلاق إصلاح وهمي |

**مبدأ التصعيد: اليقين لا التعقيد.** «هل أعرف بالضبط ما المطلوب؟» — نعم → Flash. لا (فرضية غامضة، وصف قد يكون كاذباً، قرار معماري بمفاضلات) → `Pro`.

## القاعدة الأهم

كل رقم في هذا المرجع مُقاس بشرطه. عند ترقية أو تغيير نسخة، أعد القياس — لا تفترض أن ما ثبت على 2.1.233 ثابت على نسخة لاحقة.
