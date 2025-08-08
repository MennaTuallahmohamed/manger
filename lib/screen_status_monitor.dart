import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

class ScreenStatusMonitor {
  static final ScreenStatusMonitor _instance = ScreenStatusMonitor._internal();
  factory ScreenStatusMonitor() => _instance;
  ScreenStatusMonitor._internal();

  StreamSubscription<DatabaseEvent>? _screensSubscription;
  Map<String, String> _screenStatuses = {};
  Function(Map<String, String>)? _onStatusChanged;

  void startMonitoring(String categoryId, Function(Map<String, String>) onStatusChanged) {
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
    Map<String, String> newStatuses = {};
    
    if (snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map) {
          final status = value['status'] ?? 'offline';
          newStatuses[key.toString()] = status.toString();
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

  void _printStatusChanges(Map<String, String> statuses) {
    print('📊 حالة الشاشات المحدثة:');
    statuses.forEach((screenId, status) {
      String emoji = status == 'online' ? '🟢' : '🔴';
      print('$emoji الشاشة $screenId: $status');
    });
  }

  String getScreenStatus(String screenId) {
    return _screenStatuses[screenId] ?? 'offline';
  }

  Map<String, String> getAllStatuses() {
    return Map.from(_screenStatuses);
  }

  int get onlineScreensCount {
    return _screenStatuses.values.where((status) => status == 'online').length;
  }

  int get offlineScreensCount {
    return _screenStatuses.values.where((status) => status == 'offline').length;
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