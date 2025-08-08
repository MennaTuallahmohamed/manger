import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class FirebaseTest {
  static final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  static Future<bool> testConnection() async {
    try {
      final snapshot = await _databaseRef.child('test').get();
      print('✅ تم الاتصال بقاعدة البيانات بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ في الاتصال بقاعدة البيانات: $e');
      return false;
    }
  }

  static Future<bool> testWrite() async {
    try {
      await _databaseRef.child('test').set({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message': 'اختبار الاتصال'
      });
      print('✅ تم الكتابة في قاعدة البيانات بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ في الكتابة في قاعدة البيانات: $e');
      return false;
    }
  }

  static Future<bool> testRead() async {
    try {
      final snapshot = await _databaseRef.child('screens').get();
      if (snapshot.value != null) {
        print('✅ تم قراءة البيانات بنجاح: ${snapshot.value}');
      } else {
        print('ℹ️ لا توجد بيانات في مسار screens');
      }
      return true;
    } catch (e) {
      print('❌ خطأ في قراءة البيانات: $e');
      return false;
    }
  }

  static Future<void> addSampleScreens() async {
    try {
      await _databaseRef.child('screens').update({
        'screen_1': {
          'name': 'شاشة محمد حامد',
          'status': 'online',
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'location': 'القاهرة - المعادي',
          'ip': '192.168.1.100'
        },
        'screen_2': {
          'name': 'شاشة أحمد علي',
          'status': 'offline',
          'lastSeen': DateTime.now().subtract(Duration(minutes: 5)).millisecondsSinceEpoch,
          'location': 'الإسكندرية - سموحة',
          'ip': '192.168.1.101'
        },
        'screen_3': {
          'name': 'شاشة فاطمة أحمد',
          'status': 'online',
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'location': 'الجيزة - الدقي',
          'ip': '192.168.1.102'
        },
        'screen_4': {
          'name': 'شاشة خالد محمود',
          'status': 'offline',
          'lastSeen': DateTime.now().subtract(Duration(minutes: 10)).millisecondsSinceEpoch,
          'location': 'أسيوط - المدينة',
          'ip': '192.168.1.103'
        },
        'screen_5': {
          'name': 'شاشة نور الهدى',
          'status': 'online',
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'location': 'المنصورة - شارع الجمهورية',
          'ip': '192.168.1.104'
        }
      });
      print('✅ تم إضافة البيانات التجريبية بنجاح');
    } catch (e) {
      print('❌ خطأ في إضافة البيانات التجريبية: $e');
    }
  }

  static Future<void> clearTestData() async {
    try {
      await _databaseRef.child('test').remove();
      print('✅ تم حذف البيانات التجريبية بنجاح');
    } catch (e) {
      print('❌ خطأ في حذف البيانات التجريبية: $e');
    }
  }

  static Future<void> runFullTest() async {
    print('🔍 بدء اختبار Firebase...');
    
    print('\n1. اختبار الاتصال:');
    final connectionTest = await testConnection();
    
    print('\n2. اختبار الكتابة:');
    final writeTest = await testWrite();
    
    print('\n3. اختبار القراءة:');
    final readTest = await testRead();
    
    print('\n4. إضافة بيانات تجريبية:');
    await addSampleScreens();
    
    print('\n5. اختبار القراءة بعد الإضافة:');
    await testRead();
    
    print('\n📊 نتائج الاختبار:');
    print('الاتصال: ${connectionTest ? "✅" : "❌"}');
    print('الكتابة: ${writeTest ? "✅" : "❌"}');
    print('القراءة: ${readTest ? "✅" : "❌"}');
    
    if (connectionTest && writeTest && readTest) {
      print('\n🎉 جميع الاختبارات نجحت!');
    } else {
      print('\n⚠️ بعض الاختبارات فشلت. تحقق من إعدادات Firebase.');
    }
  }
}

class FirebaseTestWidget extends StatefulWidget {
  const FirebaseTestWidget({super.key});

  @override
  State<FirebaseTestWidget> createState() => _FirebaseTestWidgetState();
}

class _FirebaseTestWidgetState extends State<FirebaseTestWidget> {
  bool _isTesting = false;
  String _testResult = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار Firebase'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isTesting ? null : () async {
                setState(() {
                  _isTesting = true;
                  _testResult = 'جاري الاختبار...';
                });
                
                await FirebaseTest.runFullTest();
                
                setState(() {
                  _isTesting = false;
                  _testResult = 'تم الانتهاء من الاختبار. تحقق من Console للتفاصيل.';
                });
              },
              child: _isTesting 
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('جاري الاختبار...'),
                    ],
                  )
                : const Text('تشغيل اختبار Firebase'),
            ),
            const SizedBox(height: 16),
            if (_testResult.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_testResult),
              ),
            const SizedBox(height: 16),
            const Text(
              'هذا الاختبار سيتحقق من:\n'
              '• الاتصال بقاعدة البيانات\n'
              '• إمكانية الكتابة\n'
              '• إمكانية القراءة\n'
              '• إضافة بيانات تجريبية',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
