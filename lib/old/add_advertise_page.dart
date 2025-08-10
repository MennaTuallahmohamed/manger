import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:easy_localization/easy_localization.dart';
import '../screen_status_monitor.dart';
import '../translation_manager.dart';

class AddAdDialog extends StatefulWidget {
  final String categoryId;
  const AddAdDialog({super.key, required this.categoryId});
  @override
  State<AddAdDialog> createState() => _AddAdDialogState();
}

class _AddAdDialogState extends State<AddAdDialog> with TickerProviderStateMixin {
  String? selectedType;
  File? mediaFile;
  final picker = ImagePicker();
  final TextEditingController textController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<QueryDocumentSnapshot> screens = [];
  List<String> selectedScreenIds = [];
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  double uploadProgress = 0.0;
  String priority = 'medium';
  int displayDuration = 10;
  bool isActive = true;
  String? selectedTemplate;
  Map<String, dynamic> screenDetails = {};
  List<String> tags = [];
  final TextEditingController tagController = TextEditingController();
  bool enableGeofencing = false;
  double? latitude;
  double? longitude;
  double radius = 100.0;
  List<String> targetAudience = [];
  String contentRating = 'general';
  bool linkToAllScreens = true;
  Map<String, String> screenStatuses = {};
  final ScreenStatusMonitor _statusMonitor = ScreenStatusMonitor();
  final TranslationManager _translationManager = TranslationManager();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    fetchScreens();
    _startStatusMonitoring();
  }

  @override
  void dispose() {
    _animationController.dispose();
    textController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    tagController.dispose();
    _statusMonitor.stopMonitoring();
    super.dispose();
  }

  Future<void> fetchScreens() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('screens')
          .where('categoryId', isEqualTo: widget.categoryId)
          .get();
      setState(() {
        screens = snapshot.docs;
      });
      for (var screen in screens) {
        final screenData = screen.data() as Map<String, dynamic>;
        screenDetails[screen.id] = {
          'name': screenData['name'] ?? 'Unknown',
          'location': screenData['location'] ?? 'Unknown',
          'status': screenData['status'] ?? 'offline',
          'resolution': screenData['resolution'] ?? '1920x1080',
          'orientation': screenData['orientation'] ?? 'landscape',
          'lastSeen': screenData['lastSeen'],
          'connectionType': screenData['connectionType'] ?? 'wifi',
          'brightness': screenData['brightness'] ?? 80,
        };
      }
    } catch (e) {
      _showSnackBar('خطأ في جلب الشاشات: $e', isError: true);
    }
  }

  void _startStatusMonitoring() {
    _statusMonitor.startMonitoring(widget.categoryId, (statuses) {
      setState(() {
        screenStatuses = statuses.cast<String, String>();
        for (String screenId in statuses.keys) {
          if (screenDetails.containsKey(screenId)) {
            screenDetails[screenId]!['status'] = statuses[screenId];
          }
        }
      });
    });
  }

  Future<bool> _requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.storage,
        Permission.photos,
      ].request();
      return statuses.values.any((status) =>
          status == PermissionStatus.granted ||
          status == PermissionStatus.limited);
    } catch (e) {
      _showSnackBar('خطأ في طلب الأذونات: $e', isError: true);
      return false;
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('أذونات مطلوبة'),
        content: const Text('يحتاج التطبيق إلى أذونات الكاميرا والملفات لاختيار الصور'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  Future<XFile?> compressImage(File file) async {
    final targetPath = file.path.replaceFirst(RegExp(r'\.(jpg|jpeg|png|heic)\$'), '_compressed.jpg');
    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 75,
      minWidth: 1080,
      minHeight: 1080,
      format: CompressFormat.jpeg,
    );
    return result;
  }

  Future<void> pickMedia(ImageSource source, bool isVideo) async {
    try {
      bool hasPermission = await _requestPermissions();
      if (!hasPermission) {
        _showPermissionDialog();
        return;
      }
      XFile? pickedFile;
      if (isVideo) {
        pickedFile = await picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 2),
        );
      } else {
        pickedFile = await picker.pickImage(
          source: source,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 60,
        );
      }
      if (pickedFile != null) {
        File file = File(pickedFile.path);
        if (!isVideo) {
          try {
            File? compressed = (await compressImage(file)) as File?;
            if (compressed != null) {
              file = compressed;
            }
          } catch (e) {
            _showSnackBar('حدث خطأ أثناء ضغط الصورة: ${e.toString()}', isError: true);
            return;
          }
        }
        if (isVideo) {
          if (file.lengthSync() > 100 * 1024 * 1024) {
            _showSnackBar('حجم الفيديو كبير جداً (أكثر من 100 ميجا)', isError: true);
            return;
          }
        } else {
          if (file.lengthSync() > 2 * 1024 * 1024) {
            _showSnackBar('الصورة ما زالت كبيرة جداً بعد الضغط (أكثر من 2 ميجا)، اختر صورة أصغر أو قلل الجودة.', isError: true);
            return;
          }
        }
        setState(() {
          mediaFile = file;
        });
        _showSnackBar('تم اختيار ${isVideo ? 'الفيديو' : 'الصورة'} بنجاح', isError: false);
      }
    } catch (e) {
      _showSnackBar('خطأ في اختيار الملف: ${e.toString()}', isError: true);
    }
  }

  Future<void> uploadAd() async {
    if (!_validateForm()) return;
    setState(() {
      isLoading = true;
      uploadProgress = 0.0;
    });
    try {
      String? url;
      if (selectedType == 'image' || selectedType == 'video') {
        if (mediaFile == null) throw 'الملف غير موجود';
        final ext = mediaFile!.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
        final ref = FirebaseStorage.instance.ref('ads/$fileName');
        final uploadTask = ref.putFile(mediaFile!);
        uploadTask.snapshotEvents.listen((taskSnapshot) {
          double progress = taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
          setState(() {
            uploadProgress = progress;
          });
        });
        await uploadTask;
        url = await ref.getDownloadURL();
      }
      final adData = {
        'type': selectedType,
        'title': titleController.text.trim(),
        'text': selectedType == 'text' ? textController.text.trim() : null,
        'description': descriptionController.text.trim(),
        'mediaUrl': url,
        'categoryId': widget.categoryId,
        'screenIds': selectedScreenIds,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'validFrom': startDate?.millisecondsSinceEpoch,
        'validTo': endDate?.millisecondsSinceEpoch,
        'startTime': startTime != null ? '${startTime!.hour}:${startTime!.minute}' : null,
        'endTime': endTime != null ? '${endTime!.hour}:${endTime!.minute}' : null,
        'priority': priority,
        'displayDuration': displayDuration,
        'isActive': isActive,
        'template': selectedTemplate,
        'tags': tags,
        'contentRating': contentRating,
        'targetAudience': targetAudience,
        'geofencing': enableGeofencing ? {
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
        } : null,
        'impressions': 0,
        'clicks': 0,
        'playCount': 0,
        'averageViewTime': 0.0,
        'screenAssignments': selectedScreenIds.map((screenId) => {
          'screenId': screenId,
          'assignedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'screenDetails': screenDetails[screenId],
        }).toList(),
      };
      final docRef = await FirebaseFirestore.instance.collection('ads').add(adData);
      await _updateScreenAssignments(docRef.id);
      await _notifyScreens(docRef.id);
      Navigator.of(context).pop();
      _showSnackBar('تم حفظ الإعلان بنجاح', isError: false);
    } catch (e) {
      _showSnackBar('خطأ في حفظ الإعلان: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        isLoading = false;
        uploadProgress = 0.0;
      });
    }
  }

  bool _validateForm() {
    if (selectedType == null) {
      _showSnackBar('اختر نوع الإعلان', isError: true);
      return false;
    }
    if (titleController.text.trim().isEmpty) {
      _showSnackBar('أدخل عنوان الإعلان', isError: true);
      return false;
    }
    if (selectedType == 'text' && textController.text.trim().isEmpty) {
      _showSnackBar('أدخل نص الإعلان', isError: true);
      return false;
    }
    if ((selectedType == 'image' || selectedType == 'video') && mediaFile == null) {
      _showSnackBar('اختر ${selectedType == 'image' ? 'صورة' : 'فيديو'}', isError: true);
      return false;
    }
    if (selectedScreenIds.isEmpty) {
      _showSnackBar('اختر شاشة واحدة على الأقل', isError: true);
      return false;
    }
    if (startDate != null && endDate != null && endDate!.isBefore(startDate!)) {
      _showSnackBar('تاريخ النهاية يجب أن يكون بعد تاريخ البداية', isError: true);
      return false;
    }
    return true;
  }

  Future<void> _updateScreenAssignments(String adId) async {
    final batch = FirebaseFirestore.instance.batch();
    for (String screenId in selectedScreenIds) {
      final screenRef = FirebaseFirestore.instance.collection('screens').doc(screenId);
      batch.update(screenRef, {
        'assignedAds': FieldValue.arrayUnion([adId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> _notifyScreens(String adId) async {
    for (String screenId in selectedScreenIds) {
      await FirebaseFirestore.instance
          .collection('screen_notifications')
          .add({
        'screenId': screenId,
        'type': 'new_ad_assignment',
        'adId': adId,
        'message': 'تم تعيين إعلان جديد',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
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

  Widget _buildFormContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'محتوى الإعلان',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: textController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'أدخل نص الإعلان هنا...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getFormContentWidget() {
    switch (selectedType) {
      case 'text':
        return _buildFormContent();
      case 'image':
        return _buildImageAdForm();
      case 'video':
        return _buildVideoAdForm();
      default:
        return _buildEmptyState();
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'اختر نوع الإعلان',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اختر نوع الإعلان من الأزرار أعلاه',
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

  Widget _buildTemplateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'قالب الإعلان',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedTemplate,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          hint: const Text('اختر قالب'),
          items: const [
            DropdownMenuItem(value: 'simple', child: Text('بسيط')),
            DropdownMenuItem(value: 'modern', child: Text('حديث')),
            DropdownMenuItem(value: 'elegant', child: Text('أنيق')),
          ],
          onChanged: (value) {
            setState(() {
              selectedType = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildImageAdForm() {
    return Container(
      key: const ValueKey('image'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: 'عنوان الإعلان',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'وصف الإعلان',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          _buildMediaPicker(false),
        ],
      ),
    );
  }

  Widget _buildVideoAdForm() {
    return Container(
      key: const ValueKey('video'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: 'عنوان الفيديو',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'وصف الفيديو',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          _buildMediaPicker(true),
        ],
      ),
    );
  }

  Widget _buildMediaPicker(bool isVideo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isVideo ? 'اختر الفيديو' : 'اختر الصورة',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => pickMedia(ImageSource.gallery, isVideo),
                icon: const Icon(Icons.photo_library),
                label: Text(isVideo ? 'من المعرض' : 'من المعرض'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => pickMedia(ImageSource.camera, isVideo),
                icon: const Icon(Icons.camera_alt),
                label: Text(isVideo ? 'الكاميرا' : 'الكاميرا'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        if (mediaFile != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم اختيار ${isVideo ? 'الفيديو' : 'الصورة'}',
                    style: TextStyle(color: Colors.green[800]),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      mediaFile = null;
                    });
                  },
                  icon: const Icon(Icons.close),
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'معلومات الإعلان الأساسية',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: 'عنوان الإعلان *',
              hintText: 'أدخل عنواناً وصفياً للإعلان',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.title, color: Colors.blue),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'وصف الإعلان',
              hintText: 'وصف مختصر للإعلان (اختياري)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.description, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreensSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('link_method'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<bool>(
                  value: linkToAllScreens,
                  onChanged: (val) {
                    setState(() {
                      linkToAllScreens = val!;
                      if (screens.isNotEmpty) {
                        selectedScreenIds.clear();
                        if (linkToAllScreens) {
                          selectedScreenIds.addAll(screens.map((s) => s.id));
                        } else {
                          selectedScreenIds.add(screens.first.id);
                        }
                      }
                    });
                  },
                  items: [
                    DropdownMenuItem(
                      value: true,
                      child: Text('auto_link'.tr()),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text('fair_distribution'.tr()),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.display_settings, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'select_screens'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi, size: 12, color: Colors.green.shade700),
                        const SizedBox(width: 2),
                        Text(
                          '${_statusMonitor.onlineScreensCount}',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off, size: 12, color: Colors.red.shade700),
                        const SizedBox(width: 2),
                        Text(
                          '${_statusMonitor.offlineScreensCount}',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${selectedScreenIds.length} ${'screens_count'.tr()}',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (screens.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'no_screens_available'.tr(),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...screens.map((screen) {
              final screenId = screen.id;
              final screenData = screenDetails[screenId];
              final name = screenData?['name'] ?? 'unknown'.tr();
              final status = screenStatuses[screenId] ?? screenData?['status'] ?? 'offline';
              final location = screenData?['location'] ?? 'unknown_location'.tr();
              final isSelected = selectedScreenIds.contains(screenId);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.orange : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: status == 'online' ? Colors.green : Colors.grey,
                        radius: 8,
                      ),
                      if (status == 'online')
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.orange.shade800 : Colors.black,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: status == 'online' ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status == 'online' ? 'online_status'.tr() : 'offline_status'.tr(),
                          style: TextStyle(
                            color: status == 'online' ? Colors.green.shade700 : Colors.red.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            status == 'online' ? Icons.wifi : Icons.wifi_off,
                            size: 14,
                            color: status == 'online' ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status == 'online' ? 'connected'.tr() : 'not_connected'.tr(),
                            style: TextStyle(
                              color: status == 'online' ? Colors.green : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: linkToAllScreens
                      ? Icon(
                          Icons.check_circle,
                          color: Colors.orange,
                        )
                      : Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedScreenIds.add(screenId);
                              } else {
                                selectedScreenIds.remove(screenId);
                              }
                            });
                          },
                          activeColor: Colors.orange,
                        ),
                  onTap: linkToAllScreens
                      ? null
                      : () {
                          setState(() {
                            if (isSelected) {
                              selectedScreenIds.remove(screenId);
                            } else {
                              selectedScreenIds.add(screenId);
                            }
                          });
                        },
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSchedulingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'جدولة الإعلان',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تاريخ البداية:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            startDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              startDate?.toString().split(' ')[0] ?? 'اختر التاريخ',
                              style: TextStyle(
                                color: startDate != null ? Colors.black : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تاريخ النهاية:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now().add(const Duration(days: 7)),
                          firstDate: startDate ?? DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            endDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              endDate?.toString().split(' ')[0] ?? 'اختر التاريخ',
                              style: TextStyle(
                                color: endDate != null ? Colors.black : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('وقت البداية:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: startTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            startTime = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              startTime?.format(context) ?? 'اختر الوقت',
                              style: TextStyle(
                                color: startTime != null ? Colors.black : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('وقت النهاية:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: endTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            endTime = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              endTime?.format(context) ?? 'اختر الوقت',
                              style: TextStyle(
                                color: endTime != null ? Colors.black : Colors.grey,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildAdvancedSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, color: Colors.purple),
              const SizedBox(width: 8),
              const Text(
                'الإعدادات المتقدمة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('الأولوية:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButton<String>(
                  value: priority,
                  onChanged: (value) {
                    setState(() {
                      priority = value!;
                    });
                  },
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('منخفضة')),
                    DropdownMenuItem(value: 'medium', child: Text('متوسطة')),
                    DropdownMenuItem(value: 'high', child: Text('عالية')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('مدة العرض (ثانية):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Expanded(
                child: Slider(
                  value: displayDuration.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11,
                  label: '$displayDuration ثانية',
                  onChanged: (value) {
                    setState(() {
                      displayDuration = value.toInt();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('تصنيف المحتوى:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButton<String>(
                  value: contentRating,
                  onChanged: (value) {
                    setState(() {
                      contentRating = value!;
                    });
                  },
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('عام')),
                    DropdownMenuItem(value: 'teen', child: Text('المراهقين')),
                    DropdownMenuItem(value: 'adult', child: Text('البالغين')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('حالة الإعلان:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Switch(
                value: isActive,
                onChanged: (value) {
                  setState(() {
                    isActive = value;
                  });
                },
                activeColor: Colors.green,
              ),
              Text(isActive ? 'نشط' : 'غير نشط'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tag, color: Colors.indigo),
              const SizedBox(width: 8),
              const Text(
                'العلامات والكلمات المفتاحية',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tagController,
                  decoration: InputDecoration(
                    labelText: 'أضف علامة',
                    hintText: 'اكتب علامة واضغط إضافة',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty && !tags.contains(value.trim())) {
                      setState(() {
                        tags.add(value.trim());
                        tagController.clear();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  if (tagController.text.trim().isNotEmpty &&
                      !tags.contains(tagController.text.trim())) {
                    setState(() {
                      tags.add(tagController.text.trim());
                      tagController.clear();
                    });
                  }
                },
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                return Chip(
                  label: Text(tag),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() {
                      tags.remove(tag);
                    });
                  },
                  backgroundColor: Colors.indigo.shade100,
                  deleteIconColor: Colors.indigo,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? screenId = screenDetails.keys.isNotEmpty ? screenDetails.keys.first : null;
    final details = screenId != null ? screenDetails[screenId] : null;
    final name = details != null ? (details['name'] ?? 'شاشة') : 'شاشة';
    final status = details != null ? (details['status'] ?? 'offline') : 'offline';
    final lastSeen = details != null && details['lastSeen'] != null
        ? details['lastSeen'] as int
        : DateTime.now().millisecondsSinceEpoch;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_box, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'add_ad'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        _translationManager.buildLanguageSelector(context),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ad_type'.tr(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTypeButton(
                                        'text',
                                        'text'.tr(),
                                        Icons.text_fields,
                                        Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildTypeButton(
                                        'image',
                                        'image'.tr(),
                                        Icons.image,
                                        Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildTypeButton(
                                        'video',
                                        'video'.tr(),
                                        Icons.videocam,
                                        Colors.purple,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildBasicInfoSection(),
                          const SizedBox(height: 16),
                          _getFormContentWidget(),
                          const SizedBox(height: 16),
                          _buildScreensSelection(),
                          const SizedBox(height: 16),
                          _buildSchedulingSection(),
                          const SizedBox(height: 16),
                          _buildAdvancedSettings(),
                          const SizedBox(height: 16),
                          _buildTagsSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: ScreenStatusCorner(
                name: name,
                status: status,
                lastSeenMillis: lastSeen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, IconData icon, Color color) {
    final isSelected = selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScreenStatusCorner extends StatelessWidget {
  final String name;
  final String status;
  final int lastSeenMillis;

  const ScreenStatusCorner({
    Key? key,
    required this.name,
    required this.status,
    required this.lastSeenMillis,
  }) : super(key: key);

  String timeAgo(int millis) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(millis));
    if (diff.inMinutes < 1) return "الآن";
    if (diff.inMinutes < 60) return "${diff.inMinutes} دقيقة";
    if (diff.inHours < 24) return "${diff.inHours} ساعة";
    return "${diff.inDays} يوم";
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Card(
        elevation: 6,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                status == "online" ? Icons.check_circle : Icons.cancel,
                color: status == "online" ? Colors.green : Colors.red,
                size: 22,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    status == "online" ? "متصل" : "غير متصل",
                    style: TextStyle(
                      color: status == "online" ? Colors.green[800] : Colors.red[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    "آخر ظهور: " + timeAgo(lastSeenMillis),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}