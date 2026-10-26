import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseSetup.initialize();
  runApp(const SchoolApp());
}

const blue = Color(0xFF244AC7);
const bg = Color(0xFFF4F7FC);
const statuses = ['حاضر', 'غائب', 'متأخر', 'مستأذن'];

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'حيدره | حضور الطلاب 2027', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: blue),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return snapshot.data == null ? const LoginScreen() : const WorkspaceGate();
      }),
  );
}

void toast(BuildContext context, String msg) {
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  Future<void> login() async {
    setState(() => loading = true);
    try { await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: password.text); }
    on FirebaseAuthException catch (e) { if (mounted) toast(context, 'تعذر الدخول: ${e.code}'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(22), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430),
    child: Card(child: Padding(padding: const EdgeInsets.all(26), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircleAvatar(radius: 34, backgroundColor: blue, child: Icon(Icons.school_rounded, color: Colors.white, size: 35)),
      const SizedBox(height: 14), const Text('منصة حيدره المدرسية', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      const Text('School Soft UI Pro | 2027'), const SizedBox(height: 28),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.mail_outline))),
      const SizedBox(height: 12), TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline))),
      const SizedBox(height: 20), SizedBox(width: double.infinity, child: FilledButton(onPressed: loading ? null : login,
        child: Padding(padding: const EdgeInsets.all(12), child: Text(loading ? 'جارٍ التحقق...' : 'تسجيل الدخول')))),
      TextButton(onPressed: () async {
        if (email.text.trim().isEmpty) { toast(context, 'أدخل بريدك أولاً'); return; }
        try { await FirebaseAuth.instance.sendPasswordResetEmail(email: email.text.trim()); if (context.mounted) toast(context, 'تم طلب إرسال رابط الاستعادة'); }
        catch (e) { if (context.mounted) toast(context, 'تعذرت العملية: $e'); }
      }, child: const Text('نسيت كلمة المرور؟')),
      const Text('تطوير أ. محمد علي حيدره', style: TextStyle(color: Colors.grey)),
    ])))))));
}

/// Memberships are provisioned by an administrator via trusted tooling.
/// Never create an admin role from client input.
class WorkspaceGate extends StatelessWidget {
  const WorkspaceGate({super.key});
  @override Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('memberships').where('uid', isEqualTo: uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Scaffold(body: Center(child: Text('خطأ في قراءة العضويات: ${snap.error}')));
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final docs = snap.data!.docs.where((d) => d.data()['active'] == true).toList();
        if (docs.isEmpty) return Scaffold(appBar: AppBar(actions: [IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))]),
          body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('الحساب مسجل، لكنه غير مرتبط بمدرسة نشطة. اطلب من مدير المنصة منحك العضوية.'))));
        return SchoolPicker(memberships: docs);
      });
  }
}

class SchoolPicker extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> memberships;
  const SchoolPicker({super.key, required this.memberships});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('اختر المدرسة'), actions: [IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))]),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: ListView(padding: const EdgeInsets.all(20), children: memberships.map((doc) {
      final m = doc.data(); final id = m['schoolId'] as String? ?? '';
      return Card(child: ListTile(leading: const Icon(Icons.school, color: blue), title: Text(m['schoolName'] as String? ?? id),
        subtitle: Text('الصلاحية: ${m['role'] ?? 'غير محددة'}'), trailing: const Icon(Icons.chevron_left),
        onTap: id.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => SchoolHome(schoolId: id, role: m['role'] as String? ?? 'viewer')))));
    }).toList()))));
}

class SchoolHome extends StatefulWidget {
  final String schoolId, role;
  const SchoolHome({super.key, required this.schoolId, required this.role});
  @override State<SchoolHome> createState() => _SchoolHomeState();
}
class _SchoolHomeState extends State<SchoolHome> {
  int tab = 0;
  String? yearId, classId;
  CollectionReference<Map<String, dynamic>> get root => FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).collection('years');
  CollectionReference<Map<String, dynamic>> get students => root.doc(yearId).collection('students');
  CollectionReference<Map<String, dynamic>> get classes => root.doc(yearId).collection('classes');
  CollectionReference<Map<String, dynamic>> get attendance => root.doc(yearId).collection('attendance');
  bool get canEdit => ['owner', 'manager', 'admin', 'teacher', 'attendance'].contains(widget.role);
  bool get canManage => ['owner', 'manager', 'admin'].contains(widget.role);
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(backgroundColor: Colors.white, title: const Text('حيدره | School Pro', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [IconButton(tooltip: 'خروج', onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))]),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: root.snapshots(), builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final years = snap.data!.docs;
      if (years.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('لا يوجد عام دراسي. أنشئ عامًا من حساب مدير المدرسة.'),
        if (canManage) FilledButton(onPressed: () => addYear(context), child: const Text('إضافة عام دراسي'))]));
      final selectedYear = years.any((d) => d.id == yearId) ? yearId! : years.first.id;
      if (yearId != selectedYear) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() { yearId = selectedYear; classId = null; }); });
      return Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: DropdownButtonFormField<String>(value: selectedYear,
          decoration: const InputDecoration(labelText: 'العام الدراسي'), items: years.map((d) => DropdownMenuItem(value: d.id, child: Text(d.data()['name'] ?? d.id))).toList(),
          onChanged: (v) => setState(() { yearId = v; classId = null; }))),
          if (canManage) IconButton(onPressed: () => addYear(context), icon: const Icon(Icons.add_circle_outline))])),
        Expanded(child: yearId == null ? const Center(child: CircularProgressIndicator()) : [dashboard(), studentsPage(), attendancePage(), reportsPage(), settingsPage()][tab]),
      ]);
    }),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.people_outline), label: 'الطلاب'),
        NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'الحضور'),
        NavigationDestination(icon: Icon(Icons.print_outlined), label: 'التقارير'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'الإعدادات')]),
  );
  Future<void> addYear(BuildContext context) async {
    final c = TextEditingController(text: '2026-2027');
    final value = await inputDialog(context, 'إضافة عام دراسي', c);
    if (value == null) return;
    await root.add({'name': value, 'createdAt': FieldValue.serverTimestamp()});
  }
  Widget dashboard() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: students.snapshots(), builder: (context, s) {
    final count = s.data?.size ?? 0;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('لوحة المتابعة', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12), Card(child: ListTile(leading: const Icon(Icons.groups, color: blue), title: const Text('إجمالي الطلاب'), trailing: Text('$count', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)))),
      Card(child: const ListTile(leading: Icon(Icons.calendar_month, color: blue), title: Text('الحضور اليومي'), subtitle: Text('افتح تبويب الحضور لتسجيل ومراجعة السجلات'))),
      const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('تذكير'), subtitle: Text('يجب إنشاء الفصول وإضافة الطلاب قبل تسجيل الحضور.'))),
    ]);
  });
  Widget classSelector({bool allowAll = false}) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: classes.snapshots(), builder: (context, snap) {
    final docs = snap.data?.docs ?? [];
    final value = docs.any((d) => d.id == classId) ? classId : null;
    return DropdownButtonFormField<String>(value: value, decoration: const InputDecoration(labelText: 'الفصل الدراسي'),
      items: [if (allowAll) const DropdownMenuItem(value: '', child: Text('كل الفصول')), ...docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.data()['name'] ?? d.id)))],
      onChanged: (v) => setState(() => classId = v));
  });
  Widget studentsPage() => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: classSelector(allowAll: true)),
      if (canManage) IconButton(tooltip: 'إضافة فصل', onPressed: addClass, icon: const Icon(Icons.create_new_folder_outlined)),
      if (canManage) IconButton(tooltip: 'إضافة طالب', onPressed: addStudent, icon: const Icon(Icons.person_add_alt_1))])),
    Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: students.orderBy('name').snapshots(), builder: (context, snap) {
      if (snap.hasError) return Center(child: Text('${snap.error}'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final docs = snap.data!.docs.where((d) => classId == null || classId == '' || d.data()['classId'] == classId).toList();
      if (docs.isEmpty) return const Center(child: Text('لا يوجد طلاب في هذا الفصل'));
      return ListView.builder(itemCount: docs.length, itemBuilder: (context, i) {
        final d = docs[i]; final v = d.data();
        return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
          leading: CircleAvatar(child: Text('${i+1}')), title: Text(v['name'] ?? ''), subtitle: Text('ولي الأمر: ${v['phone'] ?? 'غير مسجل'}'),
          trailing: canManage ? IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => addStudent(existing: d)) : null));
      });
    }))]);
  Future<void> addClass() async {
    final c = TextEditingController(); final name = await inputDialog(context, 'اسم الفصل', c);
    if (name != null) await classes.add({'name': name, 'createdAt': FieldValue.serverTimestamp()});
  }
  Future<void> addStudent({QueryDocumentSnapshot<Map<String, dynamic>>? existing}) async {
    final name = TextEditingController(text: existing?.data()['name'] ?? '');
    final phone = TextEditingController(text: existing?.data()['phone'] ?? '');
    String? selected = existing?.data()['classId'] as String? ?? classId;
    final all = await classes.get();
    if (!mounted) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: Text(existing == null ? 'إضافة طالب' : 'تعديل الطالب'), content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الطالب')),
        const SizedBox(height: 10), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم ولي الأمر')),
        const SizedBox(height: 10), DropdownButtonFormField<String>(value: all.docs.any((d) => d.id == selected) ? selected : null,
          decoration: const InputDecoration(labelText: 'الفصل'), items: all.docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.data()['name'] ?? ''))).toList(),
          onChanged: (v) => update(() => selected = v)),
      ]), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))])));
    if (ok != true || name.text.trim().isEmpty || selected == null) return;
    final data = {'name': name.text.trim(), 'phone': phone.text.trim(), 'classId': selected};
    if (existing == null) { await students.add({...data, 'createdAt': FieldValue.serverTimestamp()}); }
    else { await existing.reference.update(data); }
  }
  Widget attendancePage() => Column(children: [Padding(padding: const EdgeInsets.all(12), child: classSelector()),
    Expanded(child: classId == null || classId == '' ? const Center(child: Text('اختر الفصل لتسجيل الحضور')) : AttendanceEditor(
      schoolId: widget.schoolId, yearId: yearId!, classId: classId!, canEdit: canEdit))]);
  Widget reportsPage() => Column(children: [Padding(padding: const EdgeInsets.all(12), child: classSelector()),
    Expanded(child: classId == null || classId == '' ? const Center(child: Text('اختر الفصل لإنشاء التقرير')) : AttendanceReport(
      schoolId: widget.schoolId, yearId: yearId!, classId: classId!))]);
  Widget settingsPage() => ListView(padding: const EdgeInsets.all(16), children: [
    const Card(child: ListTile(title: Text('منصة حيدره المدرسية'), subtitle: Text('نظام حضور وغياب الطلاب 2027\nتطوير أ. محمد علي حيدره'))),
    Card(child: ListTile(title: const Text('المدرسة'), subtitle: Text(widget.schoolId))),
    Card(child: ListTile(title: const Text('الدور'), subtitle: Text(widget.role))),
    Card(child: ListTile(title: const Text('البريد الإلكتروني'), subtitle: Text(FirebaseAuth.instance.currentUser?.email ?? ''))),
  ]);
}

Future<String?> inputDialog(BuildContext context, String title, TextEditingController c) async => showDialog<String>(context: context,
  builder: (ctx) => AlertDialog(title: Text(title), content: TextField(controller: c, autofocus: true),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? null : c.text.trim()), child: const Text('حفظ'))]));

class AttendanceEditor extends StatefulWidget {
  final String schoolId, yearId, classId; final bool canEdit;
  const AttendanceEditor({super.key, required this.schoolId, required this.yearId, required this.classId, required this.canEdit});
  @override State<AttendanceEditor> createState() => _AttendanceEditorState();
}
class _AttendanceEditorState extends State<AttendanceEditor> {
  DateTime date = DateTime.now();
  final changes = <String, String>{};
  bool saving = false;
  String get dateKey => DateFormat('yyyy-MM-dd').format(date);
  CollectionReference<Map<String, dynamic>> get students => FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).collection('years').doc(widget.yearId).collection('students');
  CollectionReference<Map<String, dynamic>> get records => FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).collection('years').doc(widget.yearId).collection('attendance');
  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
      Expanded(child: Text('التاريخ: $dateKey', style: const TextStyle(fontWeight: FontWeight.bold))),
      IconButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2040));
        if (d != null) setState(() { date = d; changes.clear(); }); }, icon: const Icon(Icons.date_range))])),
    Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: students.where('classId', isEqualTo: widget.classId).snapshots(), builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final docs = snap.data!.docs.toList()..sort((a,b) => (a.data()['name'] ?? '').toString().compareTo((b.data()['name'] ?? '').toString()));
      if (docs.isEmpty) return const Center(child: Text('لا يوجد طلاب'));
      return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(key: ValueKey('${widget.classId}-$dateKey'),
        future: records.where('classId', isEqualTo: widget.classId).where('date', isEqualTo: dateKey).get(), builder: (context, existing) {
        final map = {for (final d in existing.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) d.data()['studentId'] as String: d.data()['status'] as String};
        return ListView.builder(itemCount: docs.length, itemBuilder: (context, i) {
          final d = docs[i]; final status = changes[d.id] ?? map[d.id] ?? 'حاضر';
          return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(title: Text(d.data()['name'] ?? ''),
            trailing: DropdownButton<String>(value: status, items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: widget.canEdit ? (s) { if (s != null) setState(() => changes[d.id] = s); } : null)));
        });
      });
    })),
    if (widget.canEdit) Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity,
      child: FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save), child: Text(saving ? 'جارٍ الحفظ' : 'حفظ التغييرات (${changes.length})')))),
  ]);
  Future<void> save() async {
    if (changes.isEmpty) return;
    setState(() => saving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final item in changes.entries) {
        final id = '${dateKey}_${item.key}';
        batch.set(records.doc(id), {'date': dateKey, 'classId': widget.classId, 'studentId': item.key,
          'status': item.value, 'updatedBy': FirebaseAuth.instance.currentUser!.uid, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }
      await batch.commit();
      if (mounted) { setState(changes.clear); toast(context, 'تم حفظ الحضور'); }
    } catch (e) { if (mounted) toast(context, 'فشل الحفظ: $e'); }
    finally { if (mounted) setState(() => saving = false); }
  }
}

class AttendanceReport extends StatefulWidget {
  final String schoolId, yearId, classId;
  const AttendanceReport({super.key, required this.schoolId, required this.yearId, required this.classId});
  @override State<AttendanceReport> createState() => _AttendanceReportState();
}
class _AttendanceReportState extends State<AttendanceReport> {
  DateTime date = DateTime.now();
  String get dateKey => DateFormat('yyyy-MM-dd').format(date);
  Future<void> printReport() async {
    try {
      final base = FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).collection('years').doc(widget.yearId);
      final people = await base.collection('students').where('classId', isEqualTo: widget.classId).get();
      final attend = await base.collection('attendance').where('classId', isEqualTo: widget.classId).where('date', isEqualTo: dateKey).get();
      final states = {for (final d in attend.docs) d.data()['studentId']: d.data()['status']};
      final font = await PdfGoogleFonts.notoNaskhArabicRegular();
      final doc = pw.Document();
      final sorted = people.docs.toList()..sort((a,b) => (a.data()['name'] ?? '').toString().compareTo((b.data()['name'] ?? '').toString()));
      doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, theme: pw.ThemeData.withFont(base: font, bold: font),
        textDirection: pw.TextDirection.rtl, build: (_) => [
          pw.Center(child: pw.Text('منصة حيدره المدرسية', style: pw.TextStyle(font: font, fontSize: 18))),
          pw.Center(child: pw.Text('كشف حضور الطلاب - $dateKey', style: pw.TextStyle(font: font, fontSize: 13))),
          pw.SizedBox(height: 18), pw.TableHelper.fromTextArray(context: _, headers: ['م', 'اسم الطالب', 'الحالة'],
            data: List.generate(sorted.length, (i) => ['${i+1}', sorted[i].data()['name'] ?? '', states[sorted[i].id] ?? 'غير مسجل']),
            headerStyle: pw.TextStyle(font: font), cellStyle: pw.TextStyle(font: font), cellAlignment: pw.Alignment.centerRight),
          pw.SizedBox(height: 28), pw.Text('مسؤول الحضور: _______________      مدير المدرسة: _______________', style: pw.TextStyle(font: font)),
          pw.SizedBox(height: 14), pw.Center(child: pw.Text('تطوير أ. محمد علي حيدره', style: pw.TextStyle(font: font, fontSize: 9))),
        ]));
      await Printing.layoutPdf(onLayout: (_) async => doc.save());
    } catch (e) { if (mounted) toast(context, 'تعذر إنشاء التقرير: $e'); }
  }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
      const Icon(Icons.picture_as_pdf, size: 50, color: blue), const SizedBox(height: 10),
      const Text('تقرير حضور يومي', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      Text('التاريخ: $dateKey'),
      TextButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2040));
        if (d != null) setState(() => date = d); }, icon: const Icon(Icons.date_range), label: const Text('تغيير التاريخ')),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: printReport, icon: const Icon(Icons.print), label: const Text('طباعة أو حفظ PDF'))),
    ]))),
    const Card(child: ListTile(title: Text('إشعارات أولياء الأمور'), subtitle: Text('يمكن فتح واتساب أو الرسائل يدويًا من أرقام الطلاب. لا يوجد إرسال تلقائي دون API.'))),
    OutlinedButton.icon(onPressed: () async {
      final uri = Uri.parse('sms:');
      if (await canLaunchUrl(uri)) { await launchUrl(uri); }
      else if (context.mounted) { toast(context, 'تطبيق الرسائل غير متاح'); }
    }, icon: const Icon(Icons.sms_outlined), label: const Text('فتح تطبيق SMS')),
    OutlinedButton.icon(onPressed: () async {
      final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent('تنبيه من منصة حيدره المدرسية: يرجى متابعة حضور الطالب.')}');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }, icon: const Icon(Icons.chat_outlined), label: const Text('فتح واتساب برسالة جاهزة')),
  ]);
}