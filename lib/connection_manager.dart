import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

// ==================== CONNECTION MANAGER ====================
class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  Timer? _statusTimer;
  StreamSubscription<InternetStatus>? _connectionSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? _currentScreenId;
  bool _isInitialized = false;
  bool _isDisposed = false;
  DatabaseReference? _screenRef;
  
  // إعدادات للفحص
  static const Duration _checkTimeout = Duration(seconds: 10);
  static const Duration _checkInterval = Duration(seconds: 30);
  static const Duration _minUpdateInterval = Duration(seconds: 5);
  DateTime _lastUpdate = DateTime.fromMicrosecondsSinceEpoch(0);
  
  final Connectivity _connectivity = Connectivity();
  
  Future<void> initialize(String screenId) async {
    if (_isInitialized && _currentScreenId == screenId) return;
    await _cleanup();
    _currentScreenId = screenId;
    _isInitialized = true;
    _isDisposed = false;
    _screenRef = FirebaseDatabase.instance.ref("screens/$screenId");
    await _setupDisconnectHandler();
    await _updateConnectionStatus();
    _startConnectionMonitoring();
    print('✅ تم تهيئة مدير الاتصال للشاشة: $screenId');
  }
  
  Future<void> _setupDisconnectHandler() async {
    if (_screenRef == null) return;
    try {
      await _screenRef!.onDisconnect().update({
        'name': 'الشاشة $_currentScreenId',
        'online': false,
        'lastSeen': ServerValue.timestamp,
        'connectionType': 'none',
        'disconnectedAt': ServerValue.timestamp,
        'status': 'on_disconnect_triggered',
      });
      print('🔧 تم إعداد معالج قطع الاتصال');
    } catch (e) {
      print('⚠️ خطأ في إعداد onDisconnect: $e');
    }
  }
  
  void _startConnectionMonitoring() {
    _connectionSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _statusTimer?.cancel();
    
    if (_isDisposed || _currentScreenId == null) return;
    
    try {
      _connectionSubscription = InternetConnection().onStatusChange.listen(
        (status) {
          if (!_isDisposed) {
            print('🔄 تغير حالة الإنترنت: ${_getStatusText(status)}');
            _updateConnectionStatus();
          }
        },
        onError: (error) {
          print('❌ خطأ في مراقبة حالة الإنترنت: $error');
          Timer(const Duration(seconds: 10), () => _startConnectionMonitoring());
        },
      );
      
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          if (!_isDisposed) {
            print('📶 تغير نوع الاتصال: $results');
            _updateConnectionStatus();
          }
        },
        onError: (error) {
          print('❌ خطأ في مراقبة نوع الاتصال: $error');
        },
      );
      
      _statusTimer = Timer.periodic(_checkInterval, (_) {
        if (!_isDisposed) {
          _updateConnectionStatus();
        }
      });
      
      print('🔄 تم بدء مراقبة الاتصال');
    } catch (e) {
      print('❌ خطأ في بدء مراقبة الاتصال: $e');
      Timer(const Duration(seconds: 10), _startConnectionMonitoring);
    }
  }
  
  String _getStatusText(InternetStatus status) {
    switch (status) {
      case InternetStatus.connected:
        return 'متصل';
      case InternetStatus.disconnected:
        return 'منقطع';
    }
  }
  
  Future<void> _updateConnectionStatus() async {
    if (_isDisposed || _currentScreenId == null || _screenRef == null) return;
    
    final now = DateTime.now();
    if (now.difference(_lastUpdate) < _minUpdateInterval) {
      return;
    }
    
    try {
      final bool isOnline = await InternetConnection().hasInternetAccess;
      final String connectionType = await _getConnectionType(isOnline);
      
      final Map<String, dynamic> updateData = {
        'name': 'الشاشة $_currentScreenId',
        'online': isOnline,
        'lastSeen': ServerValue.timestamp,
        'connectionType': connectionType,
        'lastChecked': now.millisecondsSinceEpoch,
        'deviceInfo': {
          'platform': 'flutter',
          'timestamp': ServerValue.timestamp,
          'lastUpdate': now.toIso8601String(),
        },
        'status': isOnline ? 'active' : 'offline',
      };
      
      await _screenRef!.update(updateData);
      _lastUpdate = now;
      print('📡 تم تحديث حالة $_currentScreenId: ${isOnline ? 'متصل' : 'منقطع'} ($connectionType)');
    } catch (e, stack) {
      print('❌ خطأ في تحديث الحالة: $e\n$stack');
      if (!_isDisposed) {
        Timer(const Duration(seconds: 5), () {
          print('🔄 إعادة محاولة تحديث الحالة...');
          _updateConnectionStatus();
        });
      }
    }
  }
  
  Future<String> _getConnectionType(bool isOnline) async {
    if (!isOnline) return 'none';
    
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty) return 'none';
      
      for (final result in results) {
        switch (result) {
          case ConnectivityResult.wifi:
            return 'wifi';
          case ConnectivityResult.mobile:
            return 'mobile';
          case ConnectivityResult.ethernet:
            return 'ethernet';
          case ConnectivityResult.bluetooth:
            return 'bluetooth';
          case ConnectivityResult.vpn:
            return 'vpn';
          case ConnectivityResult.other:
            return 'other';
          case ConnectivityResult.none:
            continue;
        }
      }
      return 'none';
    } catch (e) {
      print('⚠️ خطأ في تحديد نوع الاتصال: $e');
      return 'unknown';
    }
  }
  
  Future<void> _cleanup() async {
    print('🧹 تنظيف الموارد...');
    _statusTimer?.cancel();
    _statusTimer = null;
    
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    
    if (_screenRef != null) {
      try {
        await _screenRef!.onDisconnect().cancel();
        print('✅ تم إلغاء معالج قطع الاتصال السابق');
      } catch (e) {
        print('⚠️ خطأ في إلغاء onDisconnect: $e');
      }
    }
    _screenRef = null;
  }
  
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    print('🛑 بدء إيقاف مدير الاتصال...');
    _isDisposed = true;
    
    if (_screenRef != null && _currentScreenId != null) {
      try {
        await _screenRef!.update({
          'name': 'الشاشة $_currentScreenId',
          'online': false,
          'lastSeen': ServerValue.timestamp,
          'connectionType': 'none',
          'disposedAt': ServerValue.timestamp,
          'status': 'disposed',
          'deviceInfo': {
            'platform': 'flutter',
            'timestamp': ServerValue.timestamp,
            'action': 'disposed',
          },
        });
        print('✅ تم التحديث الأخير قبل الإغلاق');
      } catch (e) {
        print('⚠️ خطأ في التحديث الأخير: $e');
      }
    }
    
    await _cleanup();
    _isInitialized = false;
    _currentScreenId = null;
    print('🛑 تم إيقاف مدير الاتصال بنجاح');
  }
  
  // دوال للاستخدام الخارجي
  Future<bool> checkConnection() async {
    try {
      return await InternetConnection().hasInternetAccess;
    } catch (e) {
      print('❌ خطأ في فحص الاتصال: $e');
      return false;
    }
  }
  
  Future<InternetStatus> getCurrentStatus() async {
    try {
      final hasInternet = await InternetConnection().hasInternetAccess;
      return hasInternet ? InternetStatus.connected : InternetStatus.disconnected;
    } catch (e) {
      print('❌ خطأ في الحصول على الحالة: $e');
      return InternetStatus.disconnected;
    }
  }
  
  Future<void> forceUpdate() async {
    if (!_isDisposed && _isInitialized) {
      print('🔄 فرض تحديث حالة الاتصال...');
      await _updateConnectionStatus();
    } else {
      print('⚠️ لا يمكن فرض التحديث: المدير غير مهيأ أو متوقف');
    }
  }
  
  Future<void> restart() async {
    if (_currentScreenId != null) {
      print('🔄 إعادة تشغيل مدير الاتصال...');
      await initialize(_currentScreenId!);
    } else {
      print('⚠️ لا يمكن إعادة التشغيل: لا يوجد screenId');
    }
  }
  
  // معلومات حالة المدير
  bool get isActive => _isInitialized && !_isDisposed;
  String? get currentScreenId => _currentScreenId;
  bool get hasActiveMonitoring => _connectionSubscription != null && !_isDisposed;
  
  Map<String, dynamic> get debugInfo => {
    'isInitialized': _isInitialized,
    'isDisposed': _isDisposed,
    'currentScreenId': _currentScreenId,
    'hasTimer': _statusTimer != null,
    'hasInternetSubscription': _connectionSubscription != null,
    'hasConnectivitySubscription': _connectivitySubscription != null,
    'hasScreenRef': _screenRef != null,
    'lastUpdate': _lastUpdate.toIso8601String(),
    'status': isActive ? 'active' : 'inactive',
  };
  
  // إضافة دالة لتحديث اسم الشاشة
  Future<void> updateScreenName(String screenName) async {
    if (_screenRef != null && _currentScreenId != null) {
      try {
        await _screenRef!.update({
          'name': screenName,
          'nameUpdatedAt': ServerValue.timestamp,
        });
        print('✅ تم تحديث اسم الشاشة إلى: $screenName');
      } catch (e) {
        print('❌ خطأ في تحديث اسم الشاشة: $e');
      }
    }
  }
  
  // إضافة معلومات إضافية للجهاز
  Future<void> updateDeviceInfo(Map<String, dynamic> additionalInfo) async {
    if (_screenRef != null && _currentScreenId != null) {
      try {
        await _screenRef!.update({
          'deviceInfo': {
            'platform': 'flutter',
            'timestamp': ServerValue.timestamp,
            'lastUpdate': DateTime.now().toIso8601String(),
            ...additionalInfo,
          },
        });
        print('✅ تم تحديث معلومات الجهاز');
      } catch (e) {
        print('❌ خطأ في تحديث معلومات الجهاز: $e');
      }
    }
  }
}

// ==================== SCREEN DATA MODEL ====================
class ScreenData {
  final String id;
  final String name;
  final bool isOnline;
  final String connectionType;
  final DateTime? lastSeen;
  final String status;
  final Map<String, dynamic>? deviceInfo;
  
  ScreenData({
    required this.id,
    required this.name,
    required this.isOnline,
    required this.connectionType,
    this.lastSeen,
    required this.status,
    this.deviceInfo,
  });
  
  factory ScreenData.fromMap(String id, Map<dynamic, dynamic> data) {
    return ScreenData(
      id: id,
      name: data['name']?.toString() ?? 'شاشة غير محددة',
      isOnline: data['online'] as bool? ?? false,
      connectionType: data['connectionType']?.toString() ?? 'none',
      lastSeen: data['lastSeen'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['lastSeen'] as int) 
          : null,
      status: data['status']?.toString() ?? 'unknown',
      deviceInfo: data['deviceInfo'] as Map<String, dynamic>?,
    );
  }
  
  String get statusText {
    if (isOnline) return 'متصل';
    return 'غير متصل';
  }
  
  String get connectionText {
    switch (connectionType) {
      case 'wifi': return 'واي فاي';
      case 'mobile': return 'بيانات الجوال';
      case 'ethernet': return 'كابل إنترنت';
      case 'none': return 'لا يوجد اتصال';
      default: return connectionType;
    }
  }
  
  String get lastSeenText {
    if (lastSeen == null) return 'غير معروف';
    final now = DateTime.now();
    final diff = now.difference(lastSeen!);
    if (diff.inMinutes < 1) return 'منذ قليل';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }
}

// ==================== SCREEN STATUS MONITOR ====================
class ScreenStatusMonitor {
  static final ScreenStatusMonitor _instance = ScreenStatusMonitor._internal();
  factory ScreenStatusMonitor() => _instance;
  ScreenStatusMonitor._internal();
  
  StreamSubscription<DatabaseEvent>? _screensSubscription;
  Map<String, ScreenData> _screenData = {};
  Function(Map<String, ScreenData>)? _onDataChanged;
  
  void startMonitoring(String categoryId, Function(Map<String, ScreenData>) onDataChanged) {
    _onDataChanged = onDataChanged;
    _screensSubscription = FirebaseDatabase.instance
        .ref("screens")
        .onValue
        .listen((event) {
          _updateScreenData(event.snapshot);
        });
    print('👁️ بدأت مراقبة بيانات الشاشات');
  }
  
  void _updateScreenData(DataSnapshot snapshot) {
    Map<String, ScreenData> newScreenData = {};
    if (snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        if (value is Map) {
          try {
            newScreenData[key.toString()] = ScreenData.fromMap(key.toString(), value);
          } catch (e) {
            print('❌ خطأ في تحليل بيانات الشاشة $key: $e');
          }
        }
      });
    }
    
    bool hasChanges = false;
    if (_screenData.length != newScreenData.length) {
      hasChanges = true;
    } else {
      for (String screenId in newScreenData.keys) {
        final oldData = _screenData[screenId];
        final newData = newScreenData[screenId];
        if (oldData?.isOnline != newData?.isOnline || 
            oldData?.status != newData?.status) {
          hasChanges = true;
          break;
        }
      }
    }
    
    if (hasChanges) {
      _screenData = newScreenData;
      _onDataChanged?.call(_screenData);
      _printStatusChanges(newScreenData);
    }
  }
  
  void _printStatusChanges(Map<String, ScreenData> screens) {
    print("📊 حالة الشاشات المحدثة:");
    screens.forEach((screenId, screenData) {
      String emoji = screenData.isOnline ? "🟢" : "🔴";
      print("$emoji ${screenData.name} ($screenId): ${screenData.statusText} - ${screenData.connectionText}");
    });
  }
  
  ScreenData? getScreenData(String screenId) {
    return _screenData[screenId];
  }
  
  Map<String, ScreenData> getAllScreenData() {
    return Map.from(_screenData);
  }
  
  List<ScreenData> get onlineScreens {
    return _screenData.values.where((screen) => screen.isOnline).toList();
  }
  
  List<ScreenData> get offlineScreens {
    return _screenData.values.where((screen) => !screen.isOnline).toList();
  }
  
  int get onlineScreensCount => onlineScreens.length;
  int get offlineScreensCount => offlineScreens.length;
  int get totalScreensCount => _screenData.length;
  
  void stopMonitoring() {
    _screensSubscription?.cancel();
    _screensSubscription = null;
    _screenData.clear();
    _onDataChanged = null;
    print('🛑 تم إيقاف مراقبة حالة الشاشات');
  }
  
  // فلترة الشاشات حسب الحالة
  List<ScreenData> getScreensByStatus(String status) {
    return _screenData.values.where((screen) => screen.status == status).toList();
  }
  
  // فلترة الشاشات حسب نوع الاتصال
  List<ScreenData> getScreensByConnectionType(String connectionType) {
    return _screenData.values.where((screen) => screen.connectionType == connectionType).toList();
  }
  
  // الحصول على إحصائيات مفصلة
  Map<String, int> getConnectionTypeStats() {
    Map<String, int> stats = {};
    for (var screen in _screenData.values) {
      stats[screen.connectionType] = (stats[screen.connectionType] ?? 0) + 1;
    }
    return stats;
  }
  
  // البحث في الشاشات
  List<ScreenData> searchScreens(String query) {
    query = query.toLowerCase();
    return _screenData.values.where((screen) {
      return screen.name.toLowerCase().contains(query) ||
             screen.id.toLowerCase().contains(query) ||
             screen.status.toLowerCase().contains(query);
    }).toList();
  }
}

// ==================== CONNECTION MANAGER PAGE ====================
class ConnectionManagerPage extends StatefulWidget {
  const ConnectionManagerPage({Key? key}) : super(key: key);
  
  @override
  State<ConnectionManagerPage> createState() => _ConnectionManagerPageState();
}

class _ConnectionManagerPageState extends State<ConnectionManagerPage> {
  final ScreenStatusMonitor _statusMonitor = ScreenStatusMonitor();
  Map<String, ScreenData> _screenData = {};
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, online, offline
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }
  
  void _startMonitoring() {
    _statusMonitor.startMonitoring('admin_category', (screenData) {
      if (mounted) {
        setState(() {
          _screenData = screenData;
          _isLoading = false;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _statusMonitor.stopMonitoring();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    List<ScreenData> filteredScreens = _getFilteredScreens();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الاتصالات'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refresh') {
                _refreshData();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('تحديث البيانات'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري تحميل بيانات الاتصال...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: Column(
                children: [
                  // شريط الإحصائيات
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey.shade50,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                '🟢 متصل',
                                '${_statusMonitor.onlineScreensCount}',
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                '🔴 غير متصل',
                                '${_statusMonitor.offlineScreensCount}',
                                Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                '📊 المجموع',
                                '${_statusMonitor.totalScreensCount}',
                                Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        if (_searchQuery.isNotEmpty || _selectedFilter != 'all')
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_searchQuery.isNotEmpty) ...[
                                  Icon(Icons.search, size: 16, color: Colors.blue.shade700),
                                  const SizedBox(width: 4),
                                  Text('البحث: $_searchQuery', style: TextStyle(color: Colors.blue.shade700)),
                                ],
                                if (_searchQuery.isNotEmpty && _selectedFilter != 'all')
                                  Text(' | ', style: TextStyle(color: Colors.blue.shade700)),
                                if (_selectedFilter != 'all') ...[
                                  Icon(Icons.filter_list, size: 16, color: Colors.blue.shade700),
                                  const SizedBox(width: 4),
                                  Text('الفلتر: ${_getFilterText()}', style: TextStyle(color: Colors.blue.shade700)),
                                ],
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _selectedFilter = 'all';
                                    });
                                  },
                                  child: Icon(Icons.close, size: 16, color: Colors.blue.shade700),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // قائمة الشاشات
                  Expanded(
                    child: filteredScreens.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _screenData.isEmpty ? Icons.wifi_off : Icons.search_off,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _screenData.isEmpty 
                                      ? 'لا توجد شاشات متاحة'
                                      : 'لا توجد نتائج للبحث',
                                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                                if (_screenData.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _selectedFilter = 'all';
                                      });
                                    },
                                    child: const Text('مسح الفلاتر'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredScreens.length,
                            itemBuilder: (context, index) {
                              return _buildScreenCard(filteredScreens[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildStatCard(String title, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScreenCard(ScreenData screenData) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: screenData.isOnline ? Colors.green : Colors.grey,
              radius: 20,
              child: Icon(
                screenData.isOnline ? Icons.wifi : Icons.wifi_off,
                color: Colors.white,
                size: 20,
              ),
            ),
            if (screenData.isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          screenData.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${screenData.statusText} - ${screenData.connectionText}',
              style: TextStyle(
                color: screenData.isOnline ? Colors.green : Colors.grey,
                fontSize: 12,
              ),
            ),
            if (!screenData.isOnline && screenData.lastSeen != null)
              Text(
                'آخر ظهور: ${screenData.lastSeenText}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: screenData.isOnline ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                screenData.isOnline ? '🟢 متصل' : '🔴 غير متصل',
                style: TextStyle(
                  color: screenData.isOnline ? Colors.green.shade700 : Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${screenData.id}',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        onTap: () {
          _showScreenDetails(screenData);
        },
      ),
    );
  }
  
  List<ScreenData> _getFilteredScreens() {
    List<ScreenData> screens = _screenData.values.toList();
    
    // تطبيق فلتر الحالة
    switch (_selectedFilter) {
      case 'online':
        screens = screens.where((screen) => screen.isOnline).toList();
        break;
      case 'offline':
        screens = screens.where((screen) => !screen.isOnline).toList();
        break;
    }
    
    // تطبيق البحث
    if (_searchQuery.isNotEmpty) {
      screens = _statusMonitor.searchScreens(_searchQuery);
      // تطبيق الفلتر على نتائج البحث
      if (_selectedFilter != 'all') {
        screens = screens.where((screen) {
          switch (_selectedFilter) {
            case 'online': return screen.isOnline;
            case 'offline': return !screen.isOnline;
            default: return true;
          }
        }).toList();
      }
    }
    
    // ترتيب الشاشات: المتصلة أولاً ثم حسب الاسم
    screens.sort((a, b) {
      if (a.isOnline != b.isOnline) {
        return a.isOnline ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });
    
    return screens;
  }
  
  String _getFilterText() {
    switch (_selectedFilter) {
      case 'online': return 'متصل';
      case 'offline': return 'غير متصل';
      default: return 'الكل';
    }
  }
  
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String tempQuery = _searchQuery;
        return AlertDialog(
          title: const Text('البحث في الشاشات'),
          content: TextField(
            controller: TextEditingController(text: tempQuery),
            decoration: const InputDecoration(
              hintText: 'ادخل اسم الشاشة أو المعرف...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => tempQuery = value,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = tempQuery;
                });
                Navigator.of(context).pop();
              },
              child: const Text('بحث'),
            ),
          ],
        );
      },
    );
  }
  
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('فلترة الشاشات'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterOption('all', 'عرض الكل', Icons.all_inclusive),
              _buildFilterOption('online', 'المتصل فقط', Icons.wifi),
              _buildFilterOption('offline', 'غير المتصل فقط', Icons.wifi_off),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildFilterOption(String value, String label, IconData icon) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      value: value,
      groupValue: _selectedFilter,
      onChanged: (newValue) {
        setState(() {
          _selectedFilter = newValue!;
        });
        Navigator.of(context).pop();
      },
    );
  }
  
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    
    // إعادة تشغيل المراقبة
    _statusMonitor.stopMonitoring();
    _startMonitoring();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تحديث بيانات الاتصال'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _showScreenDetails(ScreenData screenData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScreenDetailsPage(screenData: screenData),
      ),
    );
  }
}

// ==================== SCREEN DETAILS PAGE ====================
class ScreenDetailsPage extends StatelessWidget {
  final ScreenData screenData;
  
  const ScreenDetailsPage({Key? key, required this.screenData}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(screenData.name),
        backgroundColor: screenData.isOnline ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقة الحالة الرئيسية
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: screenData.isOnline ? Colors.green : Colors.red,
                      ),
                      child: Icon(
                        screenData.isOnline ? Icons.wifi : Icons.wifi_off,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            screenData.statusText,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: screenData.isOnline ? Colors.green : Colors.red,
                            ),
                          ),
                          Text(
                            screenData.connectionText,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // تفاصيل الشاشة
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات الشاشة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('الاسم', screenData.name),
                    _buildDetailRow('معرف الشاشة', screenData.id),
                    _buildDetailRow('الحالة', screenData.statusText),
                    _buildDetailRow('نوع الاتصال', screenData.connectionText),
                    if (screenData.lastSeen != null)
                      _buildDetailRow('آخر ظهور', screenData.lastSeenText),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // معلومات الجهاز
            if (screenData.deviceInfo != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'معلومات الجهاز',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...screenData.deviceInfo!.entries.map(
                        (entry) => _buildDetailRow(
                          entry.key,
                          entry.value.toString(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}