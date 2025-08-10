# 🖥️ دليل نظام Online/Offline للشاشات

## 📋 نظرة عامة

هذا النظام يتيح لك مراقبة حالة الاتصال بالإنترنت للشاشات (Screens) في تطبيق الـ Admin بشكل مباشر وفوري.

---

## 🛠️ الملفات المطلوبة

### 1. `lib/connection_manager.dart`
- يدير حالة الاتصال للشاشات الفردية
- يحدث الحالة كل دقيقة في Firebase
- يستخدم `internet_connection_checker` لفحص الاتصال

### 2. `lib/screen_status_monitor.dart`
- يراقب حالة جميع الشاشات في تطبيق الـ Admin
- يحدث الواجهة فورياً عند تغيير الحالة
- يعرض إحصائيات الشاشات المتصلة وغير المتصلة

### 3. `lib/screen_app_example.dart`
- مثال لتطبيق الشاشة يوضح كيفية استخدام النظام

---

## 🚀 كيفية الاستخدام

### ✅ في تطبيق الشاشة (Screen App):

```dart
import 'connection_manager.dart';

class ScreenApp extends StatefulWidget {
  final String screenId;
  
  @override
  void initState() {
    super.initState();
    
    // تهيئة مدير الاتصال
    ConnectionManager().initialize(widget.screenId);
  }
  
  @override
  void dispose() {
    ConnectionManager().dispose();
    super.dispose();
  }
}
```

### ✅ في تطبيق الـ Admin:

```dart
import 'screen_status_monitor.dart';

class AdminApp extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    
    // بدء مراقبة حالة الشاشات
    ScreenStatusMonitor().startMonitoring(
      'category_id',
      (statuses) {
        // تحديث الواجهة عند تغيير الحالة
        setState(() {
          screenStatuses = statuses;
        });
      },
    );
  }
}
```

---

## 📊 هيكل البيانات في Firebase

```json
{
  "screens": {
    "screen_123": {
      "name": "شاشة محمد",
      "status": "online",
      "lastSeen": "2024-01-15T10:30:00Z",
      "connectionType": "wifi",
      "categoryId": "category_1"
    },
    "screen_456": {
      "name": "شاشة منة",
      "status": "offline",
      "lastSeen": "2024-01-15T09:15:00Z",
      "connectionType": "none",
      "categoryId": "category_1"
    }
  }
}
```

---

## 🎯 الميزات المتاحة

### في تطبيق الشاشة:
- ✅ فحص الاتصال كل دقيقة
- ✅ تحديث الحالة في Firebase
- ✅ عرض الحالة الحالية
- ✅ تحديث فوري عند الطلب

### في تطبيق الـ Admin:
- ✅ مراقبة حالة جميع الشاشات
- ✅ عرض إحصائيات فورية
- ✅ تحديث تلقائي للواجهة
- ✅ مؤشرات بصرية واضحة

---

## 🔧 الإعدادات

### تحديث الحالة:
- **الافتراضي**: كل 60 ثانية
- **قابل للتخصيص**: يمكن تغيير الفترة في `ConnectionManager`

### فحص الاتصال:
- يستخدم `internet_connection_checker`
- يفحص الاتصال بالإنترنت الفعلي
- يعمل على جميع المنصات

---

## 📱 واجهة المستخدم

### مؤشرات الحالة:
- 🟢 **متصل**: الشاشة متصلة بالإنترنت
- 🔴 **غير متصل**: الشاشة غير متصلة

### الإحصائيات:
- عدد الشاشات المتصلة
- عدد الشاشات غير المتصلة
- آخر تحديث للحالة

---

## 🐛 استكشاف الأخطاء

### مشاكل شائعة:

1. **الشاشة لا تظهر كمتصلة:**
   - تأكد من وجود اتصال إنترنت
   - تحقق من إعدادات Firebase
   - راجع Console للأخطاء

2. **التحديث لا يعمل:**
   - تأكد من تهيئة `ConnectionManager`
   - تحقق من `screenId` صحيح
   - راجع أذونات الشبكة

3. **الواجهة لا تتحدث:**
   - تأكد من استدعاء `setState`
   - تحقق من `ScreenStatusMonitor`
   - راجع اتصال Firebase

---

## 📞 الدعم

للمساعدة أو الاستفسارات:
- راجع Console للأخطاء
- تحقق من إعدادات Firebase
- تأكد من وجود اتصال إنترنت

---

## 🎉 تم!

الآن يمكنك مراقبة حالة الشاشات بشكل مباشر وفوري! 🚀 