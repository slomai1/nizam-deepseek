---
description: بحث ويب سريع بالعربية أو الإنجليزية عبر Playwright (مجاني، بدون API)
argument-hint: "[كلمة البحث]"
---

ابحث في Google عن كلمة المستخدم باستخدام أدوات Playwright MCP المجانية. الخطوات:

1. انتقل إلى محرك البحث: `mcp__playwright__browser_navigate` على `https://www.google.com/search?q=<كلمة البحث بعد ترميز URL>`
   - إذا كان البحث بالعربية، استخدم `https://www.bing.com/search?q=<...>` كبديل أفضل لدعم العربية.
2. اقرأ صفحة النتائج: `mcp__playwright__browser_snapshot` لاستخراج عناوين وروابط النتائج.
3. (اختياري) للدخول لنتيجة معينة استخدم `mcp__playwright__browser_click`، ولقراءة محتواها `mcp__playwright__browser_snapshot`.
4. بعد الانتهاء أغلق المتصفح: `mcp__playwright__browser_close`.

اعرض النتائج مع:

- عنوان + رابط (قابل للنقر)
- ملخص مختصر لكل نتيجة
- أعلى 5 نتائج

ملاحظات:
- هذه الطريقة مجانية 100% ولا تحتاج أي API key.
- للتوثيق التقني للمكتبات/الأطر استخدم `context7` بدلاً من هذا البحث.
- للتدقيق في مصدر معين استخدم `WebFetch` برابط مباشر.

**البحث:** $ARGUMENTS
