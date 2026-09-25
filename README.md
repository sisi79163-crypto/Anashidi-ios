# أناشيدي — iOS / SideStore

هذا المشروع يحوّل نسخة الويب إلى تطبيق iPhone عبر Capacitor وWKWebView.

## الناتج
عند تشغيل GitHub Actions ينتج ملف:

`Anashidi-1.0-unsigned.ipa`

الملف غير موقّع عمداً، لأن SideStore يعيد توقيعه بحساب Apple ID على الجهاز.

## البناء
1. ارفع محتويات هذا المجلد إلى مستودع GitHub.
2. افتح Actions > Build Anashidi iOS IPA > Run workflow.
3. نزّل Artifact باسم `Anashidi-IPA`.
4. فك الضغط لتحصل على `Anashidi-1.0-unsigned.ipa`.
5. افتح SideStore > My Apps > + واختر ملف IPA.

## ملاحظات
- Bundle ID: `com.mostafa.anashidi`
- الحد الأدنى يحدده إصدار Capacitor/Xcode المستخدم في البناء.
- روابط MP3 والصور الخارجية تحتاج اتصال إنترنت.
- استخدم فقط ملفات صوتية تملك حق نشرها أو لديك إذن باستخدامها.

## حالة التحقق
تم تصحيح إعداد التخزين المؤقت ومسار مشروع SPM. لم يتم تشغيل بناء Xcode بعد؛ هذا الأرشيف كود المشروع وليس ملف IPA جاهزًا للتثبيت.
