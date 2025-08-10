import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'connection_manager.dart';

/// مثال على تطبيق الشاشة مع نظام مراقبة الحالة
class ScreenApp extends StatefulWidget {
  final String screenId;
  
  const ScreenApp({super.key, required this.screenId});

  @override
  State<ScreenApp> createState() => _ScreenAppState();
}

class _ScreenAppState extends State<ScreenApp> with WidgetsBindingObserver {
  final ConnectionManager _connectionManager = ConnectionManager();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionManager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // تحديث الحالة عند تغيير حالة التطبيق
    if (state == AppLifecycleState.resumed) {
      _connectionManager.forceUpdate();
    }
  }

  Future<void> _initializeScreen() async {
    try {
      await _connectionManager.initialize(widget.screenId);
      setState(() {
        _isInitialized = true;
      });
      print('✅ تم تهيئة الشاشة ${widget.screenId} بنجاح');
    } catch (e) {
      print('❌ خطأ في تهيئة الشاشة: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الشاشة: ${widget.screenId}'),
        backgroundColor: _isInitialized ? Colors.green : Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isInitialized ? Icons.wifi : Icons.wifi_off),
            onPressed: () => _connectionManager.forceUpdate(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isInitialized ? Icons.check_circle : Icons.hourglass_empty,
              size: 64,
              color: _isInitialized ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              _isInitialized ? 'الشاشة متصلة ونشطة' : 'جاري التهيئة...',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'معرف الشاشة: ${widget.screenId}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _connectionManager.forceUpdate(),
              child: const Text('تحديث الحالة'),
            ),
          ],
        ),
      ),
    );
  }
}

/// مثال على كيفية استخدام تطبيق الشاشة
class ScreenAppExample extends StatelessWidget {
  const ScreenAppExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مثال تطبيق الشاشة',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
      ),
      home: const ScreenApp(screenId: 'screen_001'), // يمكن تغيير معرف الشاشة
    );
  }
}

/// دالة main لتشغيل التطبيق
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Firebase
  await Firebase.initializeApp();
  
  runApp(const ScreenAppExample());
}

/// ملاحظات مهمة:
/// 
/// 1. يجب تغيير 'screen_001' إلى معرف فريد لكل شاشة
/// 2. التطبيق يقوم بتحديث الحالة كل 10 ثوانٍ تلقائياً
/// 3. عند إغلاق التطبيق، ستتغير الحالة إلى offline تلقائياً
/// 4. يمكن الضغط على زر "تحديث الحالة" لتحديث فوري
/// 5. أيقونة الواي فاي في الشريط العلوي تظهر حالة الاتصال

