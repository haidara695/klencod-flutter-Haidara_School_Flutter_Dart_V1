# Haidara School Attendance 2027 — Flutter / Dart

تطوير أ. محمد علي حيدره

## المحتويات
- `lib/main.dart`: واجهة Flutter RTL وتسجيل الدخول والمدارس والفصول والطلاب والحضور وطباعة PDF وفتح تطبيقات واتساب/SMS.
- `lib/firebase_options.dart`: إعداد Firebase للويب من بيانات المشروع التي قدمها المالك.
- `firebase/firestore.rules`: قواعد أولية للفصل بين المدارس.
- `pubspec.yaml`: حزم Flutter المطلوبة.

## التشغيل
1. ثبّت Flutter SDK، ثم أنشئ مشروعًا بالمنصات المطلوبة: `flutter create .` داخل هذا المجلد (أو انسخ `lib` و`pubspec.yaml` إلى مشروع Flutter جديد).
2. نفّذ `flutter pub get`.
3. للويب: `flutter run -d chrome`.
4. للأندرويد: أضف تطبيق Android داخل مشروع Firebase `madarasti` واستخدم FlutterFire CLI: `dart pub global activate flutterfire_cli` ثم `flutterfire configure` لإنتاج ملفات الربط المناسبة وملف `google-services.json` عند الحاجة. إعدادات الويب وحدها لا تكفي للأندرويد.
5. فعّل Email/Password في Authentication وأنشئ المستخدم يدويًا من Firebase Console.
6. انشر قواعد `firebase/firestore.rules` بعد مراجعتها واختبارها في Emulator.
7. أنشئ عضوية المستخدم بواسطة حساب إداري موثوق في Firestore: collection `memberships`, document ID = `<schoolId>_<firebaseAuthUid>` والحقول:
   `uid`, `schoolId`, `schoolName`, `role` (`owner` أو `manager` أو `teacher` أو `attendance`), `active: true`.
8. أنشئ document في `schools/<schoolId>` من لوحة Firebase؛ بعد ذلك يستطيع المدير إضافة عام دراسي وفصول وطلاب من التطبيق.

## تنبيهات مهمة
- **هذه نسخة Dart/Flutter تأسيسية، غير مختبرة على حساب Firebase الفعلي وليست جاهزة للبيع أو بيانات طلاب حقيقية.**
- لا توجد كلمة مرور مدمجة أو صلاحيات مدير ذاتية التفعيل.
- إشعارات WhatsApp وSMS تفتح التطبيقات برسائل جاهزة **ولا ترسل تلقائيًا**. زر SMS يفتح التطبيق فقط، وزر واتساب يفتح رسالة عامة؛ تخصيص الرسائل حسب الطالب قيد التطوير.
- طباعة PDF العربية تستخدم `PdfGoogleFonts` وقد تحتاج اتصالًا بالشبكة لجلب الخط أول مرة.
- تطبيق الهاتف يحتاج بيئة Flutter SDK للبناء؛ ملفات Dart وحدها ليست APK.
- يجب تطوير اختبارات الأمان والعضويات، تقييد صلاحيات المعلم حسب الفصل، منع تغيير سجلات قديمة دون تدقيق، استعلامات مفهرسة، نسخ احتياطي، الاشتراكات، وتجربة المستخدم قبل الإنتاج.
- تصميم قواعد الحضور هنا أساس مبدئي، وليس سجل تدقيق غير قابل للتلاعب.
