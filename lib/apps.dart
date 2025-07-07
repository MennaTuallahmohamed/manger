import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_screen_page.dart';
import 'add_client.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _screens = [];
  List<String> _placesFromFirestore = [];
  bool _isLoading = true;
  late TabController _tabController;
  
  // New features: Search and filter functionality
  String _searchQuery = '';
  bool _isSearchMode = false;
  List<String> _filteredPlaces = [];
  List<String> _filteredScreens = [];
  
  // New features: Statistics
  Map<String, int> _statistics = {
    'totalPlaces': 0,
    'totalScreens': 0,
    'unassignedScreens': 0,
    'totalAds': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); 
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.wait([
      _fetchScreens(),
      _fetchPlaces(),
      _fetchStatistics(), // New feature
    ]);

    _updateFilteredLists();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchScreens() async {
    try {
      final snapshot = await _firestore.collection('screens').get();
      final screens = snapshot.docs
          .where((doc) =>
              !doc.data().containsKey('place') ||
              doc['place'] == null ||
              doc['place'].toString().trim().isEmpty)
          .map((doc) => doc.id)
          .toList();
      setState(() {
        _screens = screens;
      });
    } catch (e) {
      print('Error fetching screens: $e');
    }
  }

  Future<void> _fetchPlaces() async {
    try {
      final snapshot = await _firestore.collection('places').get();
      final places = snapshot.docs.map((doc) => doc['name'] as String).toList();
      setState(() {
        _placesFromFirestore = places;
      });
    } catch (e) {
      print('Error fetching places: $e');
    }
  }


  Future<void> _fetchStatistics() async {
    try {
      final placesSnapshot = await _firestore.collection('places').get();
      final screensSnapshot = await _firestore.collection('screens').get();
      final adsSnapshot = await _firestore.collection('ads').get();
      
      final unassignedScreens = screensSnapshot.docs
          .where((doc) =>
              !doc.data().containsKey('place') ||
              doc['place'] == null ||
              doc['place'].toString().trim().isEmpty)
          .length;

      setState(() {
        _statistics = {
          'totalPlaces': placesSnapshot.docs.length,
          'totalScreens': screensSnapshot.docs.length,
          'unassignedScreens': unassignedScreens,
          'totalAds': adsSnapshot.docs.length,
        };
      });
    } catch (e) {
      print('Error fetching statistics: $e');
    }
  }

 
  void _updateFilteredLists() {
    if (_searchQuery.isEmpty) {
      _filteredPlaces = List.from(_placesFromFirestore);
      _filteredScreens = List.from(_screens);
    } else {
      _filteredPlaces = _placesFromFirestore
          .where((place) => place.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
      _filteredScreens = _screens
          .where((screen) => screen.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _updateFilteredLists();
    });
  }

  Future<void> _showBulkOperationsDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.batch_prediction, color: Colors.purple[700]),
            ),
            const SizedBox(width: 12),
            const Text('العمليات المجمعة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEmptyPlaces() async {
    try {
      Navigator.pop(context);
      setState(() => _isLoading = true);
      
      int deletedCount = 0;
      for (String placeName in _placesFromFirestore) {
        final screensInPlace = await _firestore
            .collection('screens')
            .where('place', isEqualTo: placeName)
            .get();
        
        if (screensInPlace.docs.isEmpty) {
          final placeSnapshot = await _firestore
              .collection('places')
              .where('name', isEqualTo: placeName)
              .get();
          
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

  Future<void> _unlinkAllScreens() async {
    try {
      Navigator.pop(context);
      setState(() => _isLoading = true);
      
      final screensSnapshot = await _firestore.collection('screens').get();
      
      for (var doc in screensSnapshot.docs) {
        if (doc.data().containsKey('place')) {
          await doc.reference.update({'place': FieldValue.delete()});
        }
      }
      
      await _fetchData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم فصل ${screensSnapshot.docs.length} شاشة'),
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

  Future<void> _refreshAllData() async {
    Navigator.pop(context);
    await _fetchData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم تحديث البيانات بنجاح'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // New feature: Export data
  Future<void> _exportData() async {
    try {
      final StringBuffer csvContent = StringBuffer();
      csvContent.writeln('Type,Name,Details');
      
      for (String place in _placesFromFirestore) {
        final screensInPlace = await _firestore
            .collection('screens')
            .where('place', isEqualTo: place)
            .get();
        csvContent.writeln('Place,$place,${screensInPlace.docs.length} screens');
      }
      
      for (String screen in _screens) {
        csvContent.writeln('Screen,$screen,Unassigned');
      }
      
      // In a real app, you would save this to a file
      print('CSV Content:\n${csvContent.toString()}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم تصدير البيانات (تحقق من وحدة التحكم)'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('فشل في تصدير البيانات'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _addNewPlace() async {
    TextEditingController _placeController = TextEditingController();

    String? newPlace = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add_location, color: Colors.blue[700]),
            ),
            const SizedBox(width: 12),
            const Text('إضافة مكان جديد'),
          ],
        ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
          SnackBar(
            content: Text('تم إضافة المكان "$newPlace" بنجاح!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل في إضافة المكان'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _assignScreenToPlace(String screenId) async {
    String? selectedPlace = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.link, color: Colors.green[700]),
            ),
            const SizedBox(width: 12),
            const Text('ربط الشاشة بمكان'),
          ],
        ),
        content: SizedBox(
          height: 300,
          width: double.maxFinite,
          child: _placesFromFirestore.isEmpty
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
                  itemCount: _placesFromFirestore.length,
                  itemBuilder: (context, index) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.place, color: Colors.blue[700]),
                      ),
                      title: Text(_placesFromFirestore[index]),
                      onTap: () => Navigator.pop(context, _placesFromFirestore[index]),
                    ),
                  ),
                ),
        ),
      ),
    );

    if (selectedPlace != null) {
      try {
        await _firestore.collection('screens').doc(screenId).update({'place': selectedPlace});
        setState(() {
          _screens.remove(screenId);
          _updateFilteredLists();
        });
        await _fetchStatistics();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم ربط الشاشة بمكان "$selectedPlace"'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل في ربط الشاشة'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _deletePlace(String placeName, int index) async {
    try {
      final placeSnapshot = await _firestore
          .collection('places')
          .where('name', isEqualTo: placeName)
          .get();
      
      for (var doc in placeSnapshot.docs) {
        await doc.reference.delete();
      }

      final screensSnapshot = await _firestore
          .collection('screens')
          .where('place', isEqualTo: placeName)
          .get();
      
      for (var screenDoc in screensSnapshot.docs) {
        final screenId = screenDoc.id;
        final adsSnapshot = await _firestore
            .collection('ads')
            .where('screenId', isEqualTo: screenId)
            .get();
        
        for (var adDoc in adsSnapshot.docs) {
          await adDoc.reference.delete();
        }
        
        await _firestore.collection('screens').doc(screenId).update({
          'place': FieldValue.delete()
        });
        
        if (!_screens.contains(screenId)) {
          _screens.add(screenId);
        }
      }

      setState(() {
        _placesFromFirestore.removeAt(index);
        _updateFilteredLists();
      });
      
      await _fetchStatistics();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف المكان "$placeName"'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      print('Error deleting place: $e');
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('فشل في حذف المكان'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showDeleteConfirmation({
    required String title,
    required VoidCallback onConfirm,
    required IconData icon,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            const Text('تأكيد الحذف'),
          ],
        ),
        content: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
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
          IconButton(
            icon: Icon(_isSearchMode ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchMode = !_isSearchMode;
                if (!_isSearchMode) {
                  _searchQuery = '';
                  _updateFilteredLists();
                }
              });
            },
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.batch_prediction),
                    SizedBox(width: 8),
                    Text('العمليات المجمعة'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _showBulkOperationsDialog(),
                ),
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('تصدير البيانات'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _exportData(),
                ),
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('تحديث'),
                  ],
                ),
                onTap: () => Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _fetchData(),
                ),
              ),
            ],
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
                  _buildStatisticsTab(), // New tab
                  _buildPlacesTab(),
                  _buildScreensTab(),
                ],
              ),
            ),
    );
  }

  // New feature: Statistics tab
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
          Column(
            children: [
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
                ],
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
                  _buildInfoRow('نسبة الشاشات المربوطة', 
                      '${_statistics['totalScreens']! > 0 ? (((_statistics['totalScreens']! - _statistics['unassignedScreens']!) / _statistics['totalScreens']!) * 100).toStringAsFixed(1) : "0"}%'),
                  _buildInfoRow('متوسط الشاشات لكل مكان', 
                      '${_statistics['totalPlaces']! > 0 ? ((_statistics['totalScreens']! - _statistics['unassignedScreens']!) / _statistics['totalPlaces']!).toStringAsFixed(1) : "0"}'),
                  _buildInfoRow('متوسط الإعلانات لكل شاشة', 
                      '${(_statistics['totalScreens']! - _statistics['unassignedScreens']!) > 0 ? (_statistics['totalAds']! / (_statistics['totalScreens']! - _statistics['unassignedScreens']!)).toStringAsFixed(1) : "0"}'),
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
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
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesTab() {
    final placesToShow = _isSearchMode ? _filteredPlaces : _placesFromFirestore;
    
    return placesToShow.isEmpty
        ? _buildEmptyState(
            icon: _isSearchMode ? Icons.search_off : Icons.location_off,
            title: _isSearchMode ? 'لا توجد نتائج' : 'لا توجد أماكن',
            subtitle: _isSearchMode ? 'جرب مصطلح بحث مختلف' : 'اضغط على الزر لإضافة مكان جديد',
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: placesToShow.length,
            itemBuilder: (context, index) {
              final place = placesToShow[index];
              final originalIndex = _placesFromFirestore.indexOf(place);
              return _buildPlaceCard(place, originalIndex);
            },
          );
  }

  Widget _buildScreensTab() {
    final screensToShow = _isSearchMode ? _filteredScreens : _screens;
    
    return screensToShow.isEmpty
        ? _buildEmptyState(
            icon: _isSearchMode ? Icons.search_off : Icons.tv_off,
            title: _isSearchMode ? 'لا توجد نتائج' : 'لا توجد شاشات غير مربوطة',
            subtitle: _isSearchMode ? 'جرب مصطلح بحث مختلف' : 'جميع الشاشات مربوطة بأماكن',
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: screensToShow.length,
            itemBuilder: (context, index) {
              final screen = screensToShow[index];
              final originalIndex = _screens.indexOf(screen);
              return _buildScreenCard(screen, originalIndex);
            },
          );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
                    onPressed: () {
                      _showDeleteConfirmation(
                        title: 'هل تريد حذف الشاشة "$screen"؟',
                        icon: Icons.delete,
                        color: Colors.red,
                        onConfirm: () async {
                          try {
                            await _firestore.collection('screens').doc(screen).delete();
                            setState(() {
                              _screens.removeAt(index);
                              _updateFilteredLists();
                            });
                            await _fetchStatistics();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم حذف الشاشة "$screen"'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          } catch (e) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('فشل في حذف الشاشة'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
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

  Future<void> _editPlace(String place, int index) async {
    TextEditingController _editController = TextEditingController(text: place);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.edit, color: Colors.orange[700]),
            ),
            const SizedBox(width: 12),
            const Text('تعديل اسم المكان'),
          ],
        ),
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
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _editController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != place) {
      try {
        final snapshot = await _firestore
            .collection('places')
            .where('name', isEqualTo: place)
            .get();
        
        for (var doc in snapshot.docs) {
          await doc.reference.update({'name': newName});
        }
        
        setState(() {
          _placesFromFirestore[index] = newName;
          _updateFilteredLists();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث اسم المكان إلى "$newName"'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل في تحديث اسم المكان'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}