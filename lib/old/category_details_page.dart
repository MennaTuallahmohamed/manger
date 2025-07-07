import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:manager/add_screen_page.dart';
import 'add_advertise_page.dart';

class CategoryDetailsPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  const CategoryDetailsPage({
    Key? key,
    required this.categoryId,
    required this.categoryName,
  }) : super(key: key);

  @override
  State<CategoryDetailsPage> createState() => _CategoryDetailsPageState();
}

class _CategoryDetailsPageState extends State<CategoryDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // NEW FEATURES
  bool _isDeleting = false;
  bool _isEditingScreen = false;
  bool _isEditingAd = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScreensTab(),
                _buildAdsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.categoryName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            // Add menu options here
          },
        ),

        // NEW FEATURE: Bulk delete buttons
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'delete_all_screens') {
              await _showDeleteAllDialog('الشاشات', 'screens');
            } else if (value == 'delete_all_ads') {
              await _showDeleteAllDialog('الإعلانات', 'ads');
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete_all_screens',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('حذف جميع الشاشات', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete_all_ads',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('حذف جميع الإعلانات', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.category,
                  color: Colors.blue[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.categoryName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'معرف الفئة: ${widget.categoryId}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.blue[600],
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Colors.blue[600],
        indicatorWeight: 3,
        tabs: const [
          Tab(
            icon: Icon(Icons.tv),
            text: 'الشاشات',
          ),
          Tab(
            icon: Icon(Icons.campaign),
            text: 'الإعلانات',
          ),
        ],
      ),
    );
  }

  Widget _buildScreensTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('screens')
          .where('categoryId', isEqualTo: widget.categoryId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('حدث خطأ أثناء تحميل الشاشات');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        final screens = snapshot.data!.docs;
        if (screens.isEmpty) {
          return _buildEmptyState(
            icon: Icons.tv_off,
            title: 'لا توجد شاشات',
            subtitle: 'لم يتم إضافة أي شاشات لهذه الفئة بعد',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: screens.length,
          itemBuilder: (context, index) {
            final data = screens[index].data() as Map<String, dynamic>;
            return _buildScreenCard(screens[index].id, data);
          },
        );
      },
    );
  }

  Widget _buildAdsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('ads')
          .where('categoryId', isEqualTo: widget.categoryId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('حدث خطأ أثناء تحميل الإعلانات');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        final ads = snapshot.data!.docs;
        if (ads.isEmpty) {
          return _buildEmptyState(
            icon: Icons.campaign_outlined,
            title: 'لا توجد إعلانات',
            subtitle: 'لم يتم إضافة أي إعلانات لهذه الفئة بعد',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ads.length,
          itemBuilder: (context, index) {
            final data = ads[index].data() as Map<String, dynamic>;
            return _buildAdCard(ads[index].id, data);
          },
        );
      },
    );
  }

  Widget _buildScreenCard(String screenId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'بدون اسم';
    final ip = data['ip'] ?? 'غير محدد';
    final location = data['location'] ?? 'غير محدد';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.tv,
                    color: Colors.green[600],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditScreenDialog(screenId, data);
                    } else if (value == 'delete') {
                      _showDeleteConfirmationDialog(
                        'حذف الشاشة',
                        'هل تريد حذف الشاشة؟',
                        () => _deleteScreen(screenId),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('تعديل'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.language, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'عنوان IP: $ip',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.fingerprint, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'معرف الشاشة: $screenId',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdCard(String adId, Map<String, dynamic> data) {
    final text = data['text'] ?? 'بدون نص';
    final mediaUrl = data['mediaUrl'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.campaign,
                    color: Colors.orange[600],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // NEW FEATURE: Edit and Delete options
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditAdDialog(adId, data);
                    } else if (value == 'delete') {
                      _showDeleteConfirmationDialog(
                        'حذف الإعلان',
                        'هل تريد حذف الإعلان؟',
                        () => _deleteAd(adId),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('تعديل'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _isVideoUrl(mediaUrl)
                      ? VideoPlayerWidget(videoUrl: mediaUrl)
                      : Image.network(
                          mediaUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 100,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.error, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.fingerprint, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'معرف الإعلان: $adId',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        _showAddOptionsBottomSheet();
      },
      icon: const Icon(Icons.add),
      label: const Text('إضافة'),
      backgroundColor: Colors.blue[600],
    );
  }

  void _showAddOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ماذا تريد أن تضيف؟',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildAddOptionCard(
                      icon: Icons.tv,
                      title: 'إضافة شاشة',
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(context);
                        _showAddScreenDialog();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildAddOptionCard(
                      icon: Icons.campaign,
                      title: 'إضافة إعلان',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        _showAddAdDialog();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddOptionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
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
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
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

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.red[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _isVideoUrl(String url) {
    return url.contains('.mp4') ||
        url.contains('.mov') ||
        url.contains('.avi') ||
        url.contains('.mkv');
  }

  void _showAddScreenDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController ipController = TextEditingController();
    final TextEditingController locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.tv, color: Colors.green),
              SizedBox(width: 8),
              Text('إضافة شاشة جديدة'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'اسم الشاشة',
                    prefixIcon: const Icon(Icons.label),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ipController,
                  decoration: InputDecoration(
                    labelText: 'عنوان IP',
                    prefixIcon: const Icon(Icons.language),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: 'موقع الشاشة',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => _saveScreen(
                nameController.text,
                ipController.text,
                locationController.text,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  void _showEditScreenDialog(String screenId, Map<String, dynamic> data) {
    final TextEditingController nameController =
        TextEditingController(text: data['name']);
    final TextEditingController ipController =
        TextEditingController(text: data['ip']);
    final TextEditingController locationController =
        TextEditingController(text: data['location']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit, color: Colors.blue),
              SizedBox(width: 8),
              Text('تعديل الشاشة'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'اسم الشاشة',
                    prefixIcon: const Icon(Icons.label),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ipController,
                  decoration: InputDecoration(
                    labelText: 'عنوان IP',
                    prefixIcon: const Icon(Icons.language),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: 'موقع الشاشة',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => _updateScreen(
                screenId,
                nameController.text,
                ipController.text,
                locationController.text,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('تحديث'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveScreen(String name, String ip, String location) async {
    if (name.isEmpty || ip.isEmpty || location.isEmpty) {
      _showSnackBar('من فضلك أكمل جميع الحقول', isError: true);
      return;
    }
    try {
      await _firestore.collection('screens').add({
        'name': name.trim(),
        'ip': ip.trim(),
        'location': location.trim(),
        'categoryId': widget.categoryId,
        'categoryName': widget.categoryName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context);
      _showSnackBar('تم حفظ الشاشة بنجاح', isError: false);
    } catch (e) {
      _showSnackBar('خطأ أثناء الحفظ: $e', isError: true);
    }
  }

  Future<void> _updateScreen(
    String screenId,
    String name,
    String ip,
    String location,
  ) async {
    if (name.isEmpty || ip.isEmpty || location.isEmpty) {
      _showSnackBar('من فضلك أكمل جميع الحقول', isError: true);
      return;
    }
    try {
      await _firestore.collection('screens').doc(screenId).update({
        'name': name.trim(),
        'ip': ip.trim(),
        'location': location.trim(),
      });
      Navigator.pop(context);
      _showSnackBar('تم تحديث الشاشة بنجاح', isError: false);
    } catch (e) {
      _showSnackBar('خطأ أثناء التحديث: $e', isError: true);
    }
  }

  Future<void> _deleteScreen(String screenId) async {
    try {
      await _firestore.collection('screens').doc(screenId).delete();
      _showSnackBar('تم حذف الشاشة بنجاح', isError: false);
    } catch (e) {
      _showSnackBar('خطأ أثناء الحذف: $e', isError: true);
    }
  }

  Future<void> _deleteAd(String adId) async {
    try {
      await _firestore.collection('ads').doc(adId).delete();
      _showSnackBar('تم حذف الإعلان بنجاح', isError: false);
    } catch (e) {
      _showSnackBar('خطأ أثناء الحذف: $e', isError: true);
    }
  }

  Future<void> _showDeleteAllDialog(String type, String collection) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('حذف جميع $type'),
        content: Text('هل تريد حذف جميع $type؟'),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text("لا"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("نعم", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final query = await _firestore
            .collection(collection)
            .where('categoryId', isEqualTo: widget.categoryId)
            .get();
        for (var doc in query.docs) {
          await doc.reference.delete();
        }
        _showSnackBar('تم حذف جميع $type بنجاح', isError: false);
      } catch (e) {
        _showSnackBar('خطأ أثناء الحذف: $e', isError: true);
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog(
      String title, String message, VoidCallback onDelete) async {
    final shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      onDelete();
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAddAdDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AddAdDialog(categoryId: widget.categoryId);
      },
    );
  }

  void _showEditAdDialog(String adId, Map<String, dynamic> data) {
    final TextEditingController textController =
        TextEditingController(text: data['text']);
    File? mediaFile;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit, color: Colors.orange),
              SizedBox(width: 8),
              Text('تعديل الإعلان'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'نص الإعلان',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => _updateAd(
                adId,
                textController.text,
                data['mediaUrl'],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('تحديث'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateAd(String adId, String newText, String? oldMediaUrl) async {
    try {
      await _firestore.collection('ads').doc(adId).update({
        'text': newText,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context);
      _showSnackBar('تم تحديث الإعلان بنجاح', isError: false);
    } catch (e) {
      _showSnackBar('خطأ أثناء التحديث: $e', isError: true);
    }
  }

}