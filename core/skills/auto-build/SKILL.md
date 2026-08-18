---
name: auto-build
description: يبني مشروعًا كاملًا من خطة في الخلفية — يقرأ الوصف، يولّد خطة، يشغّل Claude Code بدون تدخلك
metadata:
  type: skill
  domain: automation, build
  priority: high
  version: 1.1
  updated: 2026-07-24
  changelog: "v1.1: +RunChecklist, +LoopReady flags, +golden-set integration, +memory lessons"
---

# 🏗️ /auto-build — بناء تلقائي في الخلفية

## متى تستخدم؟

عندك وصف مشروع وتريد Claude يبنيه كاملًا دون مراقبتك.

## الطريقة ١: عبر `claude -p` اليدوي (Git Bash)

من **Git Bash** في مجلد المشروع، اكتب وصفك في ملف ثم مرّره عبر stdin:

```bash
# اكتب الوصف في ملف
cat > prompt.txt <<'EOF'
اقرأ وافهم وصف المشروع التالي، ثم نفذه كاملًا خطوة بخطوة:

[حط وصف مشروعك هنا]

قواعد:
- لا تسألني أي سؤال
- إذا احتجت صلاحية، افترض مسموح
- سجل التقدم في progress.md بعد كل خطوة
- إذا صار خطأ، سجله وحاول تكمل
- إذا خلصت، اكتب DONE في progress.md
EOF

# شغّل البناء في الخلفية
nohup claude -p < prompt.txt > build-log.txt 2>&1 &
```

## الطريقة ٢: عبر السكريبت (أنضف)

```powershell
# من أي مكان
& "$env:USERPROFILE\.claude\scripts\auto-build.ps1" `
  -ProjectDir "C:\Projects\MyApp" `
  -Description "متجر إلكتروني بسيط: صفحة منتجات، سلة، دخول" `
  -Monitor
```

### خيارات السكريبت

| الخيار                        | وش يسوي                                                    |
| ----------------------------- | ---------------------------------------------------------- |
| `-Description "..."`          | وصف المشروع مباشر                                          |
| `-DescriptionFile "brief.md"` | وصف المشروع من ملف                                         |
| `-PlanFile "PLAN.md"`         | اسم ملف الخطة (افتراضي)                                    |
| `-Monitor`                    | يراقب التقدم ويعرض لك التحديثات                            |
| `-RunChecklist`               | يطبّق فحص `/checklist-ui` على كل واجهة أثناء البناء        |
| `-LoopReady`                  | يجهّز ملفات Loop Engineering للصيانة التلقائية بعد البناء  |
| `-TimeoutMinutes 480`         | كم دقيقة قبل القطع (افتراضي ٨ ساعات — يُطبَّق مع -Monitor) |
| `-MaxSteps 20`                | أقصى عدد خطوات (إرشادي)                                    |

### أمثلة

```powershell
# بناء بسيط
auto-build.ps1 -Description "موقع محاماة"

# بناء مع فحص الجودة
auto-build.ps1 -Description "متجر" -Monitor -RunChecklist

# بناء كامل + جودة + تجهيز للصيانة
auto-build.ps1 -Description "تطبيق" -Monitor -RunChecklist -LoopReady
```

## المراقبة

بعد التشغيل، ارجع تابع:

```powershell
# شوف آخر التحديثات
Get-Content build-log.txt -Tail 20

# شوف التقدم
Get-Content progress.md -Encoding UTF8

# أو ادخل مجلد المشروع واطلب من Claude نفسه ملخص
# اكتب: "اقرأ progress.md ولخص لي وش صار"
```

## الحماية

- المهلة (٨ ساعات افتراضي) تُطبَّق فعليًا فقط مع `-Monitor` — عند انتهائها تُوقِف العملية
- حد `MaxSteps` (٢٠) إرشادي في البرومبت — لا يمنع التجاوز برمجيًا
- إذا تعطل → يسجل `BLOCKED` في progress.md ويتوقف
- كل المخرجات في ملفات نصية — ما يضيع شيء

## تنبيهات

- اللابتوب لازم يظل شغال (نوّم الشاشة فقط مسموح، Sleep ممنوع)
- تأكد من رصيد API كافي
- أول مرة تشغّل فيها على مشروع معين، قد تحتاج تأذن لبعض الأدوات يدويًا أول مرة
