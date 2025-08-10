import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> with TickerProviderStateMixin {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref('screens');
  Map<String, dynamic> _screenStatuses = {};
  bool _isLoading = true;
  bool _isConnectedToInternet = true;
  String _filterStatus = 'all'; // all, online, offline
  String _searchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  StreamSubscription<DatabaseEvent>? _databaseSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  int _onlineCount = 0;
  int _offlineCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _checkConnectivity();
    _startListeningToScreens();
    _startListeningToConnectivity();

    _addTestData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _databaseSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _addTestData() async {
    try {
      await _databaseRef.update({
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
        }
      });
      print('تم إضافة البيانات التجريبية بنجاح');
    } catch (e) {
      print('خطأ في إضافة البيانات التجريبية: $e');
    }
  }

  void _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnectedToInternet = !connectivityResult.contains(ConnectivityResult.none);
    });
  }

  void _startListeningToConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      setState(() {
        _isConnectedToInternet = !result.contains(ConnectivityResult.none);
      });

      if (_isConnectedToInternet) {
        _startListeningToScreens();
      }
    });
  }

  void _startListeningToScreens() {
    if (!_isConnectedToInternet) {
      setState(() {
        _isLoading = false;
        _screenStatuses = {};
        _updateStatistics();
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // إلغاء الاستماع السابق إن وجد
    _databaseSubscription?.cancel();

    _databaseSubscription = _databaseRef.onValue.listen(
      (DatabaseEvent event) {
        print('تم استلام بيانات من Firebase: ${event.snapshot.value}');
        if (mounted) {
          if (event.snapshot.value != null) {
            try {
              final data = Map<String, dynamic>.from(event.snapshot.value as Map);
              print('تم تحليل البيانات بنجاح: $data');
              setState(() {
                _screenStatuses = data;
                _isLoading = false;
                _updateStatistics();
              });
            } catch (e) {
              print('خطأ في تحليل البيانات: $e');
              setState(() {
                _screenStatuses = {};
                _isLoading = false;
                _updateStatistics();
              });
            }
          } else {
            print('لا توجد بيانات في Firebase');
            setState(() {
              _screenStatuses = {};
              _isLoading = false;
              _updateStatistics();
            });
          }
        }
      },
      onError: (error) {
        print('خطأ في Firebase: $error');
        if (mounted) {
          setState(() {
            _screenStatuses = {};
            _isLoading = false;
            _updateStatistics();
          });
          _showErrorSnackBar('خطأ في الاتصال بقاعدة البيانات: $error');
        }
      },
    );
  }

  void _updateStatistics() {
    _onlineCount = _screenStatuses.values.where((screen) => screen['status'] == 'online').length;
    _offlineCount = _screenStatuses.values.where((screen) => screen['status'] == 'offline').length;
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: Colors.white,
            onPressed: () {
              _checkConnectivity();
              _startListeningToScreens();
            },
          ),
        ),
      );
    }
  }

  List<MapEntry<String, dynamic>> _getFilteredScreens() {
    var filtered = _screenStatuses.entries.toList();


    if (_filterStatus != 'all') {
      filtered = filtered.where((entry) => entry.value['status'] == _filterStatus).toList();
    }


    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((entry) {
        final name = entry.value['name']?.toString().toLowerCase() ?? '';
        final location = entry.value['location']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || location.contains(query);
      }).toList();
    }


    filtered.sort((a, b) {
      if (a.value['status'] == 'online' && b.value['status'] == 'offline') return -1;
      if (a.value['status'] == 'offline' && b.value['status'] == 'online') return 1;
      return (b.value['lastSeen'] ?? 0).compareTo(a.value['lastSeen'] ?? 0);
    });

    return filtered;
  }

  String _timeAgo(int millis) {
    if (millis == 0) return 'غير محدد';
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(millis));
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  Color _getStatusColor(String status) {
    return status == 'online' ? Colors.green : Colors.red;
  }

  IconData _getStatusIcon(String status) {
    return status == 'online' ? Icons.check_circle : Icons.error;
  }

  Future<void> _refreshData() async {
    _checkConnectivity();
    _startListeningToScreens();
  }

  @override
  Widget build(BuildContext context) {
    final filteredScreens = _getFilteredScreens();

    return Scaffold(
      appBar: AppBar(
        title: const Text('حالة الشاشات'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isConnectedToInternet)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لا يوجد اتصال بالإنترنت',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _refreshData,
                    child: Text(
                      'إعادة المحاولة',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'متصل',
                    _onlineCount.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'غير متصل',
                    _offlineCount.toString(),
                    Colors.red,
                    Icons.error,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'إجمالي',
                    (_onlineCount + _offlineCount).toString(),
                    Colors.blue,
                    Icons.tv,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'البحث في الشاشات...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip('الكل', 'all'),
                    _buildFilterChip('متصل', 'online'),
                    _buildFilterChip('غير متصل', 'offline'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('جارٍ تحميل البيانات...'),
                      ],
                    ),
                  )
                : !_isConnectedToInternet
                    ? _buildNoInternetState()
                    : filteredScreens.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _refreshData,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredScreens.length,
                              itemBuilder: (context, index) {
                                final entry = filteredScreens[index];
                                final screenId = entry.key;
                                final screen = entry.value;

                                return FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: _buildScreenCard(screenId, screen),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue.shade700,
    );
  }

  Widget _buildScreenCard(String screenId, Map screen) {
    final screenData = Map<String, dynamic>.from(screen);

    final status = screenData['status'] ?? 'offline';
    final name = screenData['name'] ?? 'شاشة غير معروفة';
    final lastSeen = screenData['lastSeen'] ?? 0;
    final location = screenData['location'] ?? '';
    final ip = screenData['ip'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: status == 'online'
                ? [Colors.green.shade50, Colors.green.shade50]
                : [Colors.red.shade50, Colors.red.shade50],
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(status),
              color: _getStatusColor(status),
              size: 24,
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (location.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '📍 $location',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (ip.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '🌐 $ip',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '⏰ ${_timeAgo(lastSeen)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status == 'online' ? 'متصل' : 'غير متصل',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          onTap: () {
            _showScreenDetails(screenId, screenData);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.tv_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد شاشات',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'لم يتم العثور على شاشات تطابق البحث'
                : 'لا توجد شاشات مسجلة في قاعدة البيانات',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoInternetState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد اتصال بالإنترنت',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تحقق من الاتصال وحاول مرة أخرى',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  void _showScreenDetails(String screenId, Map<String, dynamic> screen) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(screen['name'] ?? 'تفاصيل الشاشة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('معرف الشاشة', screenId),
            _buildDetailRow('الحالة', screen['status'] == 'online' ? 'متصل' : 'غير متصل'),
            _buildDetailRow('الموقع', screen['location'] ?? 'غير محدد'),
            _buildDetailRow('عنوان IP', screen['ip'] ?? 'غير محدد'),
            _buildDetailRow('آخر ظهور', _timeAgo(screen['lastSeen'] ?? 0)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
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
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}