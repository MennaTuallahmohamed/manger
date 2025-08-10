import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manager/add_client.dart';
import 'package:manager/add_screen_page.dart';
import 'connection_manager.dart';
import 'screen_status_monitor.dart' hide ScreenStatusMonitor;

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

// ==================== ONLINE OFFLINE MONITORING PAGE ====================
class OnlineOfflineExample extends StatefulWidget {
  const OnlineOfflineExample({super.key});

  @override
  State<OnlineOfflineExample> createState() => _OnlineOfflineExampleState();
}

class _OnlineOfflineExampleState extends State<OnlineOfflineExample> {
  final ScreenStatusMonitor _statusMonitor = ScreenStatusMonitor();
  Map<String, ScreenData> _screenData = {};
  String _selectedCategoryId = 'admin_category';
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, online, offline
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  void _startMonitoring() {
    _statusMonitor.startMonitoring(_selectedCategoryId, (screenData) {
      if (mounted) {
        setState(() {
          _screenData = screenData.cast<String, ScreenData>();
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
        title: const Text('مراقبة حالة الشاشات'),
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
      screens = _statusMonitor.searchScreens(_searchQuery).cast<ScreenData>();
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

// ==================== ADMIN SCREEN WITH INTEGRATED CONNECTION MANAGER ====================
class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _screens = [];
  List<String> _placesFromFirestore = [];
  bool _isLoading = true;
  late TabController _tabController;
  final ScreenStatusMonitor _screenStatusMonitor = ScreenStatusMonitor();
  Map<String, int> _statistics = {};
  TextEditingController _placeController = TextEditingController();
  TextEditingController _editController = TextEditingController();
  bool _isSearchMode = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
    _startScreenStatusMonitoring();
  }

  void _startScreenStatusMonitoring() {
    _screenStatusMonitor.startMonitoring('admin_category', (statuses) {
      if (mounted) {
        setState(() {
          // يمكن تحديث أي حالة مرتبطة بالاتصال هنا
        });
      }
    });
  }

  @override
  void dispose() {
    _screenStatusMonitor.stopMonitoring();
    _tabController.dispose();
    _placeController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      setState(() => _isLoading = true);
      
      // جلب الأماكن
      final placesSnapshot = await _firestore.collection('places').get();
      _placesFromFirestore = placesSnapshot.docs.map((doc) => doc['name']).where((name) => name != null).cast<String>().toList();
      
      // جلب الشاشات
      final screensSnapshot = await _firestore.collection('screens').get();
      _screens = screensSnapshot.docs.map((doc) => doc.id).toList();
      
      // حساب الإحصائيات
      await _calculateStatistics();
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في جلب البيانات: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _calculateStatistics() async {
    try {
      final totalPlaces = _placesFromFirestore.length;
      final totalScreens = _screens.length;
      
      int unassignedScreens = 0;
      for (String screen in _screens) {
        final screenDoc = await _firestore.collection('screens').doc(screen).get();
        if (!screenDoc.exists || !screenDoc.data()!.containsKey('place')) {
          unassignedScreens++;
        }
      }
      
      final adsSnapshot = await _firestore.collection('ads').get();
      final totalAds = adsSnapshot.size;
      
      _statistics = {
        'totalPlaces': totalPlaces,
        'totalScreens': totalScreens,
        'unassignedScreens': unassignedScreens,
        'totalAds': totalAds,
      };
    } catch (e) {
      print('Error calculating statistics: $e');
    }
  }

  Future<void> _addNewPlace() async {
    final newPlace = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مكان جديد'),
        content: TextField(
          controller: _placeController,
          decoration: InputDecoration(
            hintText: 'أدخل اسم المكان',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
            ),
            prefixIcon: Icon(Icons.place, color: Colors.blue[700]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _placeController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (newPlace != null && newPlace.isNotEmpty) {
      try {
        await _firestore.collection('places').add({'name': newPlace});
        await _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إضافة المكان بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إضافة المكان: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    _placeController.clear();
  }

  Future<void> _editPlace(String place, int index) async {
    _editController.text = place;
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل اسم المكان'),
        content: TextField(
          controller: _editController,
          decoration: InputDecoration(
            hintText: 'أدخل الاسم الجديد',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.orange[700]!, width: 2),
            ),
            prefixIcon: Icon(Icons.place, color: Colors.orange[700]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _editController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('تحديث'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != place) {
      try {
        final placeSnapshot = await _firestore.collection('places').where('name', isEqualTo: place).get();
        for (var doc in placeSnapshot.docs) {
          await doc.reference.update({'name': newName});
        }
        await _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث اسم المكان بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل في تحديث اسم المكان'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    _editController.clear();
  }

  Future<void> _deletePlace(String placeName, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل تريد حذف المكان "$placeName"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final placeSnapshot = await _firestore.collection('places').where('name', isEqualTo: placeName).get();
        for (var doc in placeSnapshot.docs) {
          await doc.reference.delete();
        }
        
        final screensSnapshot = await _firestore.collection('screens').where('place', isEqualTo: placeName).get();
        for (var screenDoc in screensSnapshot.docs) {
          final screenId = screenDoc.id;
          await _firestore.collection('screens').doc(screenId).update({
            'place': FieldValue.delete(),
          });
        }
        
        await _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المكان بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل في حذف المكان'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignScreenToPlace(String screenId) async {
    final placeNames = await _getPlaceNames();
    if (placeNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد أماكن متاحة للربط'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedPlace = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ربط الشاشة بمكان'),
        content: SizedBox(
          height: 300,
          width: double.maxFinite,
          child: placeNames.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('لا توجد أماكن متاحة'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: placeNames.length,
                  itemBuilder: (context, index) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.place, color: Colors.blue[700]),
                      ),
                      title: Text(placeNames[index]),
                      onTap: () => Navigator.pop(context, placeNames[index]),
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );

    if (selectedPlace != null) {
      try {
        await _firestore.collection('screens').doc(screenId).update({
          'place': selectedPlace,
        });
        await _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم ربط الشاشة بـ "$selectedPlace"'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل في ربط الشاشة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<String>> _getPlaceNames() async {
    final snapshot = await _firestore.collection('places').get();
    return snapshot.docs.map((doc) => doc['name']).where((name) => name != null).cast<String>().toList();
  }

  void _showDeleteConfirmation({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: const Text('لن يمكن التراجع عن هذا الإجراء'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إحصائيات النظام',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
            children: [
              _buildStatCard(
                title: 'إجمالي الأماكن',
                value: '${_statistics['totalPlaces']}',
                icon: Icons.location_on,
                color: Colors.blue,
              ),
              _buildStatCard(
                title: 'إجمالي الشاشات',
                value: '${_statistics['totalScreens']}',
                icon: Icons.tv,
                color: Colors.green,
              ),
              _buildStatCard(
                title: 'الشاشات غير المربوطة',
                value: '${_statistics['unassignedScreens']}',
                icon: Icons.tv_off,
                color: Colors.orange,
              ),
              _buildStatCard(
                title: 'إجمالي الإعلانات',
                value: '${_statistics['totalAds']}',
                icon: Icons.ad_units,
                color: Colors.purple,
              ),
              _buildStatCard(
                title: 'شاشات متصلة',
                value: '${_screenStatusMonitor.onlineScreensCount}',
                icon: Icons.wifi,
                color: Colors.green,
              ),
              _buildStatCard(
                title: 'شاشات غير متصلة',
                value: '${_screenStatusMonitor.offlineScreensCount}',
                icon: Icons.wifi_off,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'معلومات إضافية',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'نسبة الشاشات المربوطة',
                    '${_statistics['totalScreens']! > 0 ? (((_statistics['totalScreens']! - _statistics['unassignedScreens']!) / _statistics['totalScreens']! * 100).toStringAsFixed(1)) : '0'}%',
                  ),
                  _buildInfoRow(
                    'عدد الأماكن النشطة',
                    _statistics['totalPlaces'] != null ? '${_statistics['totalPlaces']}' : '0',
                  ),
                  _buildInfoRow(
                    'متوسط الشاشات لكل مكان',
                    _statistics['totalPlaces'] != null && _statistics['totalPlaces']! > 0
                        ? ((_statistics['totalScreens']! - _statistics['unassignedScreens']!) / _statistics['totalPlaces']!).toStringAsFixed(1)
                        : '0',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'العمليات المجمعة',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.delete_sweep, color: Colors.red[700]),
                        title: const Text('حذف جميع الأماكن الفارغة'),
                        subtitle: const Text('حذف الأماكن التي لا تحتوي على شاشات'),
                        onTap: () => _deleteEmptyPlaces(),
                      ),
                      ListTile(
                        leading: Icon(Icons.link_off, color: Colors.orange[700]),
                        title: const Text('فصل جميع الشاشات'),
                        subtitle: const Text('إلغاء ربط جميع الشاشات من الأماكن'),
                        onTap: () => _unlinkAllScreens(),
                      ),
                      ListTile(
                        leading: Icon(Icons.refresh, color: Colors.green[700]),
                        title: const Text('تحديث البيانات'),
                        subtitle: const Text('إعادة تحميل جميع البيانات'),
                        onTap: () => _refreshAllData(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesTab() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        itemCount: _placesFromFirestore.length,
        itemBuilder: (context, index) {
          final place = _placesFromFirestore[index];
          return _buildPlaceCard(place, index);
        },
      ),
    );
  }

  Widget _buildPlaceCard(String place, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaceScreensPage(placeName: place),
            ),
          );
        },
        onLongPress: () {
          _showDeleteConfirmation(
            title: 'هل تريد حذف المكان "$place"؟',
            icon: Icons.delete,
            color: Colors.red,
            onConfirm: () async {
              await _deletePlace(place, index);
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.place, color: Colors.blue[700], size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اضغط للعرض • اضغط مطولاً للحذف',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add, color: Colors.green[700]),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddAdPage(placeName: place),
                          ),
                        );
                      },
                      tooltip: 'إضافة إعلان',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.edit, color: Colors.orange[700]),
                      onPressed: () => _editPlace(place, index),
                      tooltip: 'تعديل',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreensTab() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        itemCount: _screens.length,
        itemBuilder: (context, index) {
          return _buildScreenCard(_screens[index], index);
        },
      ),
    );
  }

  Widget _buildScreenCard(String screen, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.tv, color: Colors.purple[700], size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    screen,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'شاشة غير مربوطة بمكان',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.link, color: Colors.blue[700]),
                    onPressed: () => _assignScreenToPlace(screen),
                    tooltip: 'ربط بمكان',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[700]),
                    onPressed: () => _showDeleteConfirmation(
                      title: 'هل تريد حذف الشاشة "$screen"؟',
                      icon: Icons.delete,
                      color: Colors.red,
                      onConfirm: () async {
                        try {
                          await _firestore.collection('screens').doc(screen).delete();
                          await _fetchData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حذف الشاشة بنجاح'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('فشل في حذف الشاشة'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                    tooltip: 'حذف',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEmptyPlaces() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الأماكن الفارغة'),
        content: const Text('هل أنت متأكد من حذف جميع الأماكن التي لا تحتوي على شاشات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        Navigator.pop(context);
        setState(() => _isLoading = true);
        int deletedCount = 0;
        for (String placeName in _placesFromFirestore) {
          final screensInPlace = await _firestore.collection('screens').where('place', isEqualTo: placeName).get();
          if (screensInPlace.docs.isEmpty) {
            final placeSnapshot = await _firestore.collection('places').where('name', isEqualTo: placeName).get();
            for (var doc in placeSnapshot.docs) {
              await doc.reference.delete();
              deletedCount++;
            }
          }
        }
        await _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف $deletedCount مكان فارغ'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل في حذف الأماكن الفارغة'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _unlinkAllScreens() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فصل جميع الشاشات'),
        content: const Text('هل أنت متأكد من فصل جميع الشاشات عن الأماكن؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('فصل', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        Navigator.pop(context);
        setState(() => _isLoading = true);
        final screensSnapshot = await _firestore.collection('screens').get();
        for (var doc in screensSnapshot.docs) {
          if (doc.data().containsKey('place')) {
            await doc.reference.update({
              'place': FieldValue.delete(),
            });
          }
        }
        await _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم فصل جميع الشاشات'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل في فصل الشاشات'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _refreshAllData() async {
    await _fetchData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تحديث البيانات'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: _isSearchMode
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'البحث...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(color: Colors.black87),
                onChanged: _onSearchChanged,
              )
            : const Text('لوحة التحكم'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        actions: [
          // Screen Status Icon - Navigate to ConnectionManager
          IconButton(
            icon: Icon(
              _screenStatusMonitor.offlineScreensCount > 0
                  ? Icons.warning
                  : Icons.check_circle,
              color: _screenStatusMonitor.offlineScreensCount > 0
                  ? Colors.orangeAccent
                  : Colors.greenAccent,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OnlineOfflineExample(),
                ),
              );
            },
            tooltip: _screenStatusMonitor.offlineScreensCount > 0
                ? 'يوجد ${_screenStatusMonitor.offlineScreensCount} شاشات غير متصلة'
                : 'جميع الشاشات متصلة',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _isSearchMode = !_isSearchMode;
                _searchQuery = '';
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue[700],
          labelColor: Colors.blue[700],
          unselectedLabelColor: Colors.grey[600],
          tabs: const [
            Tab(
              icon: Icon(Icons.analytics),
              text: 'الإحصائيات',
            ),
            Tab(
              icon: Icon(Icons.location_on),
              text: 'الأماكن',
            ),
            Tab(
              icon: Icon(Icons.tv),
              text: 'الشاشات',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewPlace,
        backgroundColor: Colors.blue[700],
        icon: const Icon(Icons.add_location),
        label: const Text('إضافة مكان'),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري التحميل...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStatisticsTab(),
                  _buildPlacesTab(),
                  _buildScreensTab(),
                ],
              ),
            ),
    );
  }
}
