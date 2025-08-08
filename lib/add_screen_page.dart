import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart'; 

class PlaceScreensPage extends StatefulWidget {
  final String placeName;

  const PlaceScreensPage({Key? key, required this.placeName}) : super(key: key);

  @override
  State<PlaceScreensPage> createState() => _PlaceScreensPageState();
}

class _PlaceScreensPageState extends State<PlaceScreensPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, List<Map<String, dynamic>>> _adsByScreen = {};
  Map<String, List<Map<String, dynamic>>> _filteredAdsByScreen = {};
  bool _loading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String _searchQuery = '';
  String _selectedAdType = 'all';
  String _sortBy = 'date';
  bool _isAscending = false;
  bool _isGridView = false;
  final TextEditingController _searchController = TextEditingController();
  

  int _totalAds = 0;
  int _totalScreens = 0;
  Map<String, int> _adTypeStats = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final screensSnapshot = await _firestore
          .collection('screens')
          .where('place', isEqualTo: widget.placeName)
          .get();

      final screenIds = screensSnapshot.docs.map((doc) => doc.id).toList();

      final adsSnapshot = await _firestore.collection('ads').get();

      Map<String, List<Map<String, dynamic>>> tempMap = {};

      for (String screenId in screenIds) {
        final relatedAds = adsSnapshot.docs.where((adDoc) {
          final List screenIds = adDoc['screenIds'] ?? [];
          return screenIds.contains(screenId);
        }).map((doc) => {
              'id': doc.id,
              'timestamp': doc['timestamp'] ?? Timestamp.now(),
              ...doc.data(),
            }).toList();

        tempMap[screenId] = relatedAds;
      }

      _calculateStatistics(tempMap);
      
      setState(() {
        _adsByScreen = tempMap;
        _loading = false;
      });
      
      _applyFiltersAndSort();
      _animationController.forward();
    } catch (e) {
      print('Error fetching ads: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  void _calculateStatistics(Map<String, List<Map<String, dynamic>>> data) {
    _totalScreens = data.keys.length;
    _totalAds = 0;
    _adTypeStats.clear();
    
    for (var ads in data.values) {
      _totalAds += ads.length;
      for (var ad in ads) {
        String adType = ad['adType'] ?? 'unknown';
        _adTypeStats[adType] = (_adTypeStats[adType] ?? 0) + 1;
      }
    }
  }

  void _applyFiltersAndSort() {
    Map<String, List<Map<String, dynamic>>> filtered = {};
    
    for (var entry in _adsByScreen.entries) {
      List<Map<String, dynamic>> filteredAds = entry.value.where((ad) {
      
        bool matchesSearch = _searchQuery.isEmpty ||
            (ad['adText']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            ad['id'].toLowerCase().contains(_searchQuery.toLowerCase());
        
       
        bool matchesType = _selectedAdType == 'all' || ad['adType'] == _selectedAdType;
        
        return matchesSearch && matchesType;
      }).toList();
      
      filteredAds.sort((a, b) {
        int comparison = 0;
        switch (_sortBy) {
          case 'date':
            Timestamp aTime = a['timestamp'] ?? Timestamp.now();
            Timestamp bTime = b['timestamp'] ?? Timestamp.now();
            comparison = aTime.compareTo(bTime);
            break;
          case 'type':
            comparison = (a['adType'] ?? '').compareTo(b['adType'] ?? '');
            break;
          case 'name':
            comparison = (a['adText'] ?? '').compareTo(b['adText'] ?? '');
            break;
        }
        return _isAscending ? comparison : -comparison;
      });
      
      filtered[entry.key] = filteredAds;
    }
    
    setState(() {
      _filteredAdsByScreen = filtered;
    });
  }

  void _showStatisticsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.analytics, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('إحصائيات الإعلانات'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('إجمالي الشاشات', _totalScreens.toString(), Icons.tv),
            _buildStatRow('إجمالي الإعلانات', _totalAds.toString(), Icons.campaign),
            const Divider(),
            const Text('توزيع الإعلانات حسب النوع:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._adTypeStats.entries.map((entry) => _buildStatRow(
              _getAdTypeLabel(entry.key),
              entry.value.toString(),
              _getAdTypeIconData(entry.key),
            )),
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

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  IconData _getAdTypeIconData(String adType) {
    switch (adType) {
      case 'text': return Icons.text_fields;
      case 'image': return Icons.image;
      case 'video': return Icons.play_circle_outline;
      default: return Icons.help_outline;
    }
  }

  void _shareAdContent(Map<String, dynamic> ad) {
    String content = '';
    switch (ad['adType']) {
      case 'text':
        content = ad['adText'] ?? '';
        break;
      case 'image':
        content = 'صورة إعلانية: ${ad['adImageUrl'] ?? ''}';
        break;
      case 'video':
        content = 'فيديو إعلاني: ${ad['adVideoUrl'] ?? ''}';
        break;
    }
    
    Share.share(
      'إعلان من ${widget.placeName}\n\n$content',
      subject: 'إعلان من ${widget.placeName}',
    );
  }

  void _showAdDetails(Map<String, dynamic> ad) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            _buildAdTypeIcon(ad['adType']),
            const SizedBox(width: 8),
            Expanded(child: Text(_getAdTypeLabel(ad['adType']))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('معرف الإعلان', ad['id']),
            _buildDetailRow('النوع', _getAdTypeLabel(ad['adType'])),
            if (ad['timestamp'] != null)
              _buildDetailRow('تاريخ الإنشاء', _formatTimestamp(ad['timestamp'])),
            if (ad['adText'] != null && ad['adText'].isNotEmpty)
              _buildDetailRow('النص', ad['adText']),
            if (ad['screenIds'] != null)
              _buildDetailRow('عدد الشاشات', ad['screenIds'].length.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _shareAdContent(ad),
            child: const Text('مشاركة'),
          ),
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
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _exportData() async {
    String csvData = 'Screen ID,Ad ID,Ad Type,Ad Text,Created Date\n';
    
    for (var entry in _adsByScreen.entries) {
      for (var ad in entry.value) {
        csvData += '${entry.key},${ad['id']},${ad['adType'] ?? ''},';
        csvData += '"${ad['adText']?.replaceAll('"', '""') ?? ''}",';
        csvData += '${ad['timestamp'] != null ? _formatTimestamp(ad['timestamp']) : ''}\n';
      }
    }
    
    await Share.share(
      csvData,
      subject: 'بيانات إعلانات ${widget.placeName}',
    );
  }

  Future<void> _deleteAd(String adId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الإعلان؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _firestore.collection('ads').doc(adId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حذف الإعلان بنجاح'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _fetchData();
      } catch (e) {
        print('Error deleting ad: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل في حذف الإعلان'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
      
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _applyFiltersAndSort();
            },
            decoration: InputDecoration(
              hintText: 'البحث في الإعلانات...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                        _applyFiltersAndSort();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
             
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedAdType,
                      isExpanded: true,
                      onChanged: (value) {
                        setState(() {
                          _selectedAdType = value!;
                        });
                        _applyFiltersAndSort();
                      },
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('جميع الأنواع')),
                        DropdownMenuItem(value: 'text', child: Text('نصي')),
                        DropdownMenuItem(value: 'image', child: Text('صورة')),
                        DropdownMenuItem(value: 'video', child: Text('فيديو')),
                      ],
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
             
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      isExpanded: true,
                      onChanged: (value) {
                        setState(() {
                          _sortBy = value!;
                        });
                        _applyFiltersAndSort();
                      },
                      items: const [
                        DropdownMenuItem(value: 'date', child: Text('التاريخ')),
                        DropdownMenuItem(value: 'type', child: Text('النوع')),
                        DropdownMenuItem(value: 'name', child: Text('النص')),
                      ],
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: IconButton(
                  icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward),
                  onPressed: () {
                    setState(() {
                      _isAscending = !_isAscending;
                    });
                    _applyFiltersAndSort();
                  },
                ),
              ),
              
              const SizedBox(width: 8),
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('شاشات ${widget.placeName}'),
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
            icon: const Icon(Icons.analytics),
            onPressed: _showStatisticsDialog,
            tooltip: 'إحصائيات',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportData();
                  break;
                case 'refresh':
                  _fetchData();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('تصدير البيانات'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('تحديث'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[300],
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('جاري التحميل...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : _adsByScreen.isEmpty
              ? _buildEmptyState()
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      _buildSearchAndFilters(),
                      const SizedBox(height: 8),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchData,
                          child: _isGridView
                              ? _buildGridView()
                              : _buildListView(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredAdsByScreen.length,
      itemBuilder: (context, index) {
        final entry = _filteredAdsByScreen.entries.elementAt(index);
        return _buildScreenCard(entry.key, entry.value);
      },
    );
  }

  Widget _buildGridView() {
    List<Map<String, dynamic>> allAds = [];
    for (var entry in _filteredAdsByScreen.entries) {
      for (var ad in entry.value) {
        allAds.add({...ad, 'screenId': entry.key});
      }
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: allAds.length,
      itemBuilder: (context, index) {
        final ad = allAds[index];
        return _buildGridAdCard(ad);
      },
    );
  }

  Widget _buildGridAdCard(Map<String, dynamic> ad) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildAdTypeIcon(ad['adType']),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getAdTypeLabel(ad['adType']),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'details':
                        _showAdDetails(ad);
                        break;
                      case 'share':
                        _shareAdContent(ad);
                        break;
                      case 'delete':
                        _deleteAd(ad['id']);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16),
                          SizedBox(width: 8),
                          Text('التفاصيل'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share, size: 16),
                          SizedBox(width: 8),
                          Text('مشاركة'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _buildAdContent(ad['adType'], ad['adText'], ad['adImageUrl'], ad['adVideoUrl']),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Text(
              'شاشة ${ad['screenId']}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
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
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد شاشات أو إعلانات',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اسحب للأسفل للتحديث',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenCard(String screenId, List<Map<String, dynamic>> ads) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.tv,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'شاشة $screenId',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${ads.length} إعلان',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (ads.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لا توجد إعلانات',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...ads.map((ad) => _buildAdCard(ad)).toList(),
        ],
      ),
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final adType = ad['adType'];
    final adText = ad['adText'];
    final imageUrl = ad['adImageUrl'];
    final videoUrl = ad['adVideoUrl'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAdTypeIcon(adType),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getAdTypeLabel(adType),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.blue),
                  onPressed: () => _showAdDetails(ad),
                  tooltip: 'التفاصيل',
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.green),
                  onPressed: () => _shareAdContent(ad),
                  tooltip: 'مشاركة',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteAd(ad['id']),
                  tooltip: 'حذف الإعلان',
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildAdContent(adType, adText, imageUrl, videoUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildAdTypeIcon(String adType) {
    IconData icon;
    Color color;

    switch (adType) {
      case 'text':
        icon = Icons.text_fields;
        color = Colors.green;
        break;
      case 'image':
        icon = Icons.image;
        color = Colors.orange;
        break;
      case 'video':
        icon = Icons.play_circle_outline;
        color = Colors.purple;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _getAdTypeLabel(String adType) {
    switch (adType) {
      case 'text':
        return 'إعلان نصي';
      case 'image':
        return 'إعلان بصورة';
      case 'video':
        return 'إعلان بفيديو';
      default:
        return 'نوع غير معروف';
    }
  }

  Widget _buildAdContent(String adType, String? adText, String? imageUrl, String? videoUrl) {
    switch (adType) {
      case 'text':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            adText ?? 'النص غير متوفر',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        );

      case 'image':
        if (imageUrl != null && imageUrl.isNotEmpty) {
          return Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: 200,
              minHeight: 100,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FittedBox(
                fit: BoxFit.cover,
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  alignment: Alignment.center,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('فشل تحميل الصورة', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          return Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, size: 32, color: Colors.grey),
                  SizedBox(height: 4),
                  Text('الصورة غير متوفرة', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

      case 'video':
        if (videoUrl != null && videoUrl.isNotEmpty) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: VideoPlayerWidget(videoUrl: videoUrl),
            ),
          );
        } else {
          return Container(
            height: 100,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 14, 6, 6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_off, size: 32, color: Colors.grey),
                  SizedBox(height: 4),
                  Text('الفيديو غير متوفر', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

      default:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('نوع غير معروف', style: TextStyle(color: Colors.grey)),
        );
    }
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
            _controller.setLooping(true);
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 8),
              Text('فشل تحميل الفيديو', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('جاري تحميل الفيديو...'),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// صفحة جديدة: كل الشاشات والإعلانات المرتبطة بها
class AllScreensAdsPage extends StatefulWidget {
  const AllScreensAdsPage({Key? key}) : super(key: key);

  @override
  State<AllScreensAdsPage> createState() => _AllScreensAdsPageState();
}

class _AllScreensAdsPageState extends State<AllScreensAdsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, List<Map<String, dynamic>>> _adsByScreen = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() { _loading = true; });
    try {
      final screensSnapshot = await _firestore.collection('screens').get();
      final screenIds = screensSnapshot.docs.map((doc) => doc.id).toList();
      final adsSnapshot = await _firestore.collection('ads').get();
      Map<String, List<Map<String, dynamic>>> tempMap = {};
      for (String screenId in screenIds) {
        final relatedAds = adsSnapshot.docs.where((adDoc) {
          final List screenIds = adDoc['screenIds'] ?? [];
          return screenIds.contains(screenId);
        }).map((doc) => {
              'id': doc.id,
              'title': doc['title'] ?? '',
              'type': doc['type'] ?? '',
              'createdAt': doc['createdAt'],
            }).toList();
        tempMap[screenId] = relatedAds;
      }
      setState(() {
        _adsByScreen = tempMap;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كل الشاشات والإعلانات المرتبطة'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _adsByScreen.length,
              itemBuilder: (context, index) {
                final entry = _adsByScreen.entries.elementAt(index);
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          'شاشة ${entry.key}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                      if (entry.value.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('لا توجد إعلانات لهذه الشاشة', style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ...entry.value.map((ad) => ListTile(
                              leading: Icon(
                                ad['type'] == 'text'
                                    ? Icons.text_fields
                                    : ad['type'] == 'image'
                                        ? Icons.image
                                        : ad['type'] == 'video'
                                            ? Icons.play_circle_outline
                                            : Icons.help_outline,
                                color: Colors.blue,
                              ),
                              title: Text(ad['title'] ?? 'بدون عنوان'),
                              subtitle: Text('النوع: ${ad['type']}'),
                              trailing: ad['createdAt'] != null
                                  ? Text(
                                      (ad['createdAt'] as Timestamp).toDate().toString().split('.')[0],
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    )
                                  : null,
                            )),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ElevatedButton(
//   onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AllScreensAdsPage())),
//   child: Text('كل الشاشات والإعلانات'),
// ),