---
description: اكتشاف نوع المشروع تلقائياً وتحميل المهارات المناسبة — يحلل الكود ويقترح أفضل الأدوات
argument-hint: "[اختياري: مسار المشروع | auto]"
---

أنت الآن في وضع **إعداد المشروع الذكي**. حلل المشروع الحالي واكتشف تقنياته، ثم حمّل المهارات المناسبة.

## الخطوة 1: اكتشاف نوع المشروع 🔍

شغّل هذا الأمر لاكتشاف التقنيات:

```bash
echo "=== تحليل المشروع: $(pwd) ===" && \
echo "" && \
echo "📁 الملفات الرئيسية:" && \
ls -1 package.json composer.json pubspec.yaml Cargo.toml go.mod Gemfile pom.xml wp-config.php next.config.* astro.config.* svelte.config.* nuxt.config.* Dockerfile Makefile 2>/dev/null | sed 's/^/  ✅ /' && \
echo "" && \
echo "📂 المجلدات الدليلية:" && \
(for d in src app pages components plugins themes node_modules vendor .git; do if [ -d "$d" ]; then echo "  📁 $d"; fi; done) && \
echo "" && \
echo "📊 إحصائيات سريعة:" && \
echo "  TypeScript: $(find . -name '*.ts' -o -name '*.tsx' 2>/dev/null | wc -l) ملفات" && \
echo "  JavaScript: $(find . -name '*.js' -o -name '*.jsx' 2>/dev/null | wc -l) ملفات" && \
echo "  PHP: $(find . -name '*.php' 2>/dev/null | wc -l) ملفات" && \
echo "  Python: $(find . -name '*.py' 2>/dev/null | wc -l) ملفات" && \
echo "  Dart: $(find . -name '*.dart' 2>/dev/null | wc -l) ملفات" && \
echo "  CSS: $(find . -name '*.css' -o -name '*.scss' 2>/dev/null | wc -l) ملفات"
```

## الخطوة 2: الأدوات المناسبة حسب نوع المشروع

بناءً على الملفات المكتشفة، استخدم الأدوات المناسبة:

### WordPress (يحتوي wp-config.php أو wp-content/)

- الوكيل: `wordpress-master`
- المهارات: استخدم مهارات wp-* المتاحة من المكونات الإضافية (wp-* plugins)
- الجودة: `quick-check` أو `deep-review` حسب الحجم

### Next.js / React (يحتوي next.config.* أو package.json مع next/react)

- الوكيل: `nextjs-developer`
- المهارات: `code-review`, `checklist-ui`
- النشر: `land-and-deploy` (إن كان Vercel)

### Flutter / Dart (يحتوي pubspec.yaml)

- الوكيل: `flutter-expert`
- الجودة: `code-review`

### Python (يحتوي requirements.txt أو pyproject.toml)

- الوكيل: `python-pro`
- الجودة: `code-review`

### TypeScript / Node.js (يحتوي package.json مع typescript)

- الوكيل: `typescript-pro`
- الجودة: `code-review`

### مشروع جديد / غير محدد

- `project-context` — بناء سياق المشروع
- `graphify` — رسم بياني معرفي
- `design-shotgun` — إن كان فيه واجهات

## الخطوة 3: التحميل 🚀

**إذا `$ARGUMENTS` = `auto`:** حمّل المهارات المناسبة تلقائياً (بدون سؤال).

**إذا `$ARGUMENTS` فارغ:** اعرض المهارات المقترحة واسأل المستخدم أيها يريد تحميلها.

**إذا `$ARGUMENTS` = مسار:** حلل ذلك المسار بدل المجلد الحالي.

---

## الخطوة 4: احفظ النتيجة في PROJECT_CONTEXT

بعد التحميل، حدّث `PROJECT_CONTEXT.md` بإضافة قسم `### المهارات المحملة` مع قائمة المهارات النشطة.

---

**الهدف**: $ARGUMENTS (إذا فارغ = المجلد الحالي)
