import 'dart:async';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:firebase_database/firebase_database.dart';

class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  Timer? _statusTimer;
  String? _currentScreenId;
  bool _isInitialized = false;

  
  Future<void> initialize(String screenId) async {
    if (_isInitialized && _currentScreenId == screenId) return;
    
    _currentScreenId = screenId;
    _isInitialized = true;
    
    await _updateConnectionStatus();
    
    
    _startPeriodicUpdates();
    
    print('✅ تم تهيئة مدير الاتصال للشاشة: $screenId');
  }

  void _startPeriodicUpdates() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _updateConnectionStatus();
    });
  }

  Future<void> _updateConnectionStatus() async {
    try {
      bool hasConnection = await InternetConnectionChecker().hasConnection;
      String status = hasConnection ? 'online' : 'offline';
      
      if (_currentScreenId != null) {
        await FirebaseDatabase.instance
            .ref("screens/$_currentScreenId")
            .update({
          'status': status,
          'lastSeen': ServerValue.timestamp,
          'connectionType': hasConnection ? 'wifi' : 'none',
        });
        
        print('📡 تم تحديث حالة الشاشة $_currentScreenId: $status');
      }
    } catch (e) {
      print('❌ خطأ في تحديث حالة الاتصال: $e');
    }
  }

  void dispose() {
    _statusTimer?.cancel();
    _statusTimer = null;
    _isInitialized = false;
    _currentScreenId = null;
    print('🛑 تم إيقاف مدير الاتصال');
  }

  Future<bool> checkConnection() async {
    try {
      return await InternetConnectionChecker().hasConnection;
    } catch (e) {
      print('❌ خطأ في فحص الاتصال: $e');
      return false;
    }
  }

  Future<void> forceUpdate() async {
    await _updateConnectionStatus();
  }
} 