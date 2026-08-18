---
description: اختبار تلقائي + تصحيح ذاتي — يتحقق من التغييرات ويصلح الأخطاء تلقائياً
argument-hint: [ملف | مسار | last-change]
---

نفّذ workflow `auto-verify` على الهدف المحدد.

## الاستخدام

```
/auto-verify                  # يختبر آخر تغييرات git
/auto-verify <ملف>           # يختبر ملف محدد
/auto-verify <مسار>          # يختبر كل الملفات في المسار
```

## سير العمل

```
اكتشاف التغييرات ← اختبار (playwright + LSP + lint) ← تصنيف النتيجة ← تصحيح ← تقرير
                                                              ↑_____________|
                                        (مصفوفة 5 أفعال: موثوق/قابل للتشخيص/تعارض/لا قيد جديد/انحلال)
```

## أنواع الاختبارات التلقائية

| نوع الملف            | الاختبار                      |
| -------------------- | ----------------------------- |
| `.tsx` `.jsx` `.vue` | Playwright browser screenshot |
| `.css` `.scss`       | Visual regression             |
| `.ts` `.js` `.py`    | LSP diagnostics + unit tests  |
| `.php`               | PHP LSP + phpstan             |
| API routes           | HTTP status check             |

**الهدف**: $ARGUMENTS (إذا فارغ = `git diff --name-only`)
