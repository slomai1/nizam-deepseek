---
description: تبديل أوضاع DeepSeek — نمط الكود (دقة) أو النمط الإبداعي (توسع) أو النمط المتوازن
argument-hint: [code | creative | balanced]
---

أنت الآن في وضع **ضبط ملف DeepSeek**. نفّذ التعديلات التالية حسب النمط المطلوب.

## الأوضاع الثلاثة 🎚️

### 🎯 نمط الكود (`code`)
للبرمجة والتحليل الدقيق:
- `effortLevel`: **high**
- `temperature`: **0.1** (دقة قصوى)
- `thinking`: deep مع max tokens 32K
- الأسلوب: مباشر، تقني، دقيق
- استخدم `thinking` قبل كل تعديل

### 🎨 النمط الإبداعي (`creative`)
للتصميم والأفكار الجديدة:
- `effortLevel`: **xhigh**
- `temperature`: **0.8** (تنوع وإبداع)
- `thinking`: deep مع max tokens 64K
- الأسلوب: تخيلي، متعدد الاحتمالات
- قدّم 3 بدائل على الأقل لكل فكرة

### ⚖️ النمط المتوازن (`balanced`) — الافتراضي
للمهام العامة:
- `effortLevel`: **medium**
- `temperature`: **0.3** (توازن)
- `thinking`: auto
- الأسلوب: منظم، واضح، عملي

---
**النمط المطلوب**: $ARGUMENTS (إذا فارغ، استخدم balanced)

## تعليمات التنفيذ

عدّل إعدادات `.claude/settings.json`:
- `effortLevel` حسب النمط
- أضف تعليق في بداية الجلسة يوضح النمط النشط

ثم أكد التغيير برسالة:
```
✅ تم تفعيل نمط [الاسم] — temperature=[X] effort=[Y]
```
