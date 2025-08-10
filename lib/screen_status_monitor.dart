import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

class ScreenStatusMonitor {
  static final ScreenStatusMonitor _instance = ScreenStatusMonitor._internal();
  factory ScreenStatusMonitor() => _instance;
  ScreenStatusMonitor._internal();

  StreamSubscription<DatabaseEvent>? _screensSubscription;
  Map<String, bool> _screenStatuses = {};
  Function(Map<String, bool>)? _onStatusChanged;

  void startMonitoring(String categoryId, Function(Map<String, bool>) onStatusChanged) {
    _onStatusChanged = onStatusChanged;
    
    _screensSubscription = FirebaseDatabase.instance
        .ref("screens")
        .onValue
        .listen((event) {
          _updateScreenStatuses(event.snapshot);
        });
    
    print('👁️ بدأت مراقبة حالة الشاشات للفئة: $categoryId');
  }

  void _updateScreenStatuses(DataSnapshot snapshot) {
    Map<String, bool> newStatuses = {};
    
    if (snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map) {
          final onlineStatus = value["online"] ?? false;
          newStatuses[key.toString()] = onlineStatus as bool;
        }
      });
    }
    
    bool hasChanges = false;
    if (_screenStatuses.length != newStatuses.length) {
      hasChanges = true;
    } else {
      for (String screenId in newStatuses.keys) {
        if (_screenStatuses[screenId] != newStatuses[screenId]) {
          hasChanges = true;
          break;
        }
      }
    }
    
    if (hasChanges) {
      _screenStatuses = newStatuses;
      _onStatusChanged?.call(_screenStatuses);
      
      _printStatusChanges(newStatuses);
    }
  }

  void _printStatusChanges(Map<String, bool> statuses) {
    print("📊 حالة الشاشات المحدثة:");
    statuses.forEach((screenId, isOnline) {
      String emoji = isOnline ? "🟢" : "🔴";
      print("$emoji الشاشة $screenId: ${isOnline ? "متصل" : "غير متصل"}");
    });
  }

  String getScreenStatus(String screenId) {
    return (_screenStatuses[screenId] ?? false) ? "online" : "offline";
  }

  Map<String, bool> getAllStatuses() {
    return Map.from(_screenStatuses);
  }

  int get onlineScreensCount {
    return _screenStatuses.values.where((isOnline) => isOnline).length;
  }

  int get offlineScreensCount {
    return _screenStatuses.values.where((isOnline) => !isOnline).length;
  }

  void stopMonitoring() {
    _screensSubscription?.cancel();
    _screensSubscription = null;
    _screenStatuses.clear();
    _onStatusChanged = null;
    print('🛑 تم إيقاف مراقبة حالة الشاشات');
  }

  Future<void> refreshStatuses(String categoryId) async {
    try {
            final snapshot = await FirebaseDatabase.instance
            .ref("screens")
            .get();
      
      _updateScreenStatuses(snapshot);
    } catch (e) {
      print('❌ خطأ في تحديث الحالات: $e');
    }
  }
} 