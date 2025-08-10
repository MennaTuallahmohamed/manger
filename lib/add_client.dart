import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddAdPage extends StatefulWidget {
  final String placeName;
  const AddAdPage({Key? key, required this.placeName}) : super(key: key);

  @override
  State<AddAdPage> createState() => _AddAdPageState();
}

class _AddAdPageState extends State<AddAdPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _screens = [];
  List<String> _selectedScreens = [];
  String _adType = 'text';
  String? _adDescription;
  File? _selectedFile;

  bool _isLoading = false;
  bool _isUploadingFile = false;
  int _currentStep = 0;

  
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isHighPriority = false;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _fetchScreensForPlace();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchScreensForPlace() async {
    try {
      final snapshot = await _firestore
          .collection('screens')
          .where('place', isEqualTo: widget.placeName)
          .get();
      setState(() {
        _screens = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      });
    } catch (e) {
      _showErrorMessage('خطأ في تحميل الشاشات: $e');
    }
  }

  Future<void> _pickFile() async {
    setState(() => _isUploadingFile = true);
    try {
      if (_adType == 'text') {
        await _showTextInputDialog();
      } else {
        final pickedFile = _adType == 'image'
            ? await _picker.pickImage(source: ImageSource.gallery)
            : await _picker.pickVideo(source: ImageSource.gallery);
        if (pickedFile != null) {
          if (_adType == 'image') {
            final croppedFile = await _cropImage(pickedFile.path);
            if (croppedFile != null) {
              setState(() {
                _selectedFile = croppedFile as File?;
                _adDescription = null;
              });
            }
          } else {
            setState(() {
              _selectedFile = File(pickedFile.path);
              _adDescription = null;
            });
          }
        }
      }
    } catch (e) {
      _showErrorMessage('خطأ في اختيار الملف: $e');
    } finally {
      setState(() => _isUploadingFile = false);
    }
  }

  Future<CroppedFile?> _cropImage(String path) async {
    return await ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.original,
            ],
        ),
      ],
    );
  }

  Future<void> _showTextInputDialog() async {
    final controller = TextEditingController(text: _adDescription ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.text_fields, color: Colors.blue),
            SizedBox(width: 8),
            Text('محتوى الإعلان النصي'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'اكتب نص الإعلان هنا...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
      onPressed: () {
        if (controller.text.trim().isNotEmpty) {
          Navigator.pop(context, controller.text.trim());
        }
      },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        _adDescription = result;
        _selectedFile = null;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: Colors.blue),
        ),
        child: child!,
      ),
    );
    if (selectedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = selectedDate;
        } else {
          _endDate = selectedDate;
        }
      });
    }
  }

  Future<void> _submitAd() async {
    if (!_validateForm()) return;
    setState(() => _isLoading = true);
    try {
      String? downloadUrl;
      if (_selectedFile != null) {
        downloadUrl = await _uploadFile();
      }

      await _firestore.collection('ads').add({
        'adType': _adType,
        'adText': _adDescription ?? '',
        'adImageUrl': downloadUrl ?? '',
        'screenIds': _selectedScreens,
        'place': widget.placeName,
        'timestamp': FieldValue.serverTimestamp(),
        'startDate': _startDate,
        'endDate': _endDate,
        'priority': _isHighPriority ? 'high' : 'normal',
      });

      _showSuccessMessage('تم إضافة الإعلان بنجاح!');
      Navigator.pop(context);
    } catch (e) {
      _showErrorMessage('حدث خطأ أثناء إضافة الإعلان: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _uploadFile() async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString() +
        (_adType == 'image' ? '.jpg' : '.mp4');
    final ref = FirebaseStorage.instance.ref().child('ads/$fileName');
    final uploadTask = await ref.putFile(_selectedFile!);
    return await uploadTask.ref.getDownloadURL();
  }

  bool _validateForm() {
    if (_selectedScreens.isEmpty) {
      _showErrorMessage('يرجى اختيار شاشة واحدة على الأقل');
      return false;
    }
    if (_selectedFile == null && _adDescription == null) {
      _showErrorMessage('يرجى إدخال محتوى الإعلان');
      return false;
    }
    if ((_startDate != null && _endDate == null) ||
        (_startDate == null && _endDate != null)) {
      _showErrorMessage('يرجى تحديد كلا التاريخين (البداية والنهاية)');
      return false;
    }
    if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      _showErrorMessage('تاريخ الانتهاء يجب أن يكون بعد تاريخ البدء');
      return false;
    }
    return true;
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _darkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_adType == 'text')
            Text(
              _adDescription ?? 'لا يوجد نص',
              style: TextStyle(fontSize: 16, color: _darkMode ? Colors.white : Colors.black),
            )
          else if (_selectedFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _adType == 'image'
                  ? Image.file(_selectedFile!, height: 200, fit: BoxFit.cover)
                  : Container(
                      height: 200,
                      alignment: Alignment.center,
                      color: Colors.grey[200],
                      child: const Icon(Icons.videocam, size: 50),
                    ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: _darkMode ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('إضافة إعلان جديد'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(_darkMode ? Icons.wb_sunny : Icons.nightlight),
              onPressed: () => setState(() => _darkMode = !_darkMode),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildAdTypeStep(),
                  _buildContentStep(),
                  _buildScheduleStep(),
                  _buildScreenSelectionStep(),
                ],
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          for (int i = 0; i < 4; i++)
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _currentStep ? Colors.blue : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < 3) const SizedBox(width: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(icon: Icons.calendar_today, title: 'جدولة الإعلان', subtitle: 'حدد وقت عرض الإعلان'),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _selectDate(context, true),
                  icon: const Icon(Icons.date_range),
                  label: Text(_startDate?.toLocal().toString().split(" ").first ?? 'اختر تاريخ البدء'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _selectDate(context, false),
                  icon: const Icon(Icons.date_range),
                  label: Text(_endDate?.toLocal().toString().split(" ").first ?? 'اختر تاريخ الانتهاء'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('إعلان ذو أولوية'),
            value: _isHighPriority,
            onChanged: (value) => setState(() => _isHighPriority = value),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader({required IconData icon, required String title, required String subtitle}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.blue[600], size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, offset: Offset(0, -2), blurRadius: 4)],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('السابق'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_currentStep == 3 ? _submitAd : _nextStep),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_currentStep == 3 ? 'نشر الإعلان' : 'التالي'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(icon: Icons.edit, title: 'محتوى الإعلان', subtitle: 'أضف المحتوى الخاص بالإعلان'),
          const SizedBox(height: 30),
          _buildContentCard(),
          const SizedBox(height: 20),
          _buildAddContentButton(),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (_) => Container(
                padding: const EdgeInsets.all(16),
                child: _buildPreviewCard(),
              ),
            ),
            icon: const Icon(Icons.remove_red_eye),
            label: const Text('معاينة الإعلان'),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard() {
    if (_adDescription != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text(
                  'النص المختار:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _adDescription!,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }
    if (_selectedFile != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _adType == 'image' ? Icons.image : Icons.videocam,
                  color: _adType == 'image' ? Colors.green[600] : Colors.orange[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'الملف المختار:',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_adType == 'image')
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedFile!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam, size: 48, color: Colors.grey[600]),
                    const SizedBox(height: 8),
                    Text(
                      'فيديو محدد',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              _selectedFile!.path.split('/').last,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(
            _adType == 'text' ? Icons.text_fields :
            _adType == 'image' ? Icons.image : Icons.videocam,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'لم يتم اختيار محتوى بعد',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddContentButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isUploadingFile ? null : _pickFile,
        icon: _isUploadingFile 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _adType == 'text' ? Icons.edit :
                _adType == 'image' ? Icons.image : Icons.videocam,
              ),
        label: Text(
          _isUploadingFile ? 'جاري التحميل...' :
          _adType == 'text' ? 'كتابة النص' :
          _adType == 'image' ? 'اختيار صورة' : 'اختيار فيديو',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildAdTypeStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.category,
            title: 'نوع الإعلان',
            subtitle: 'اختر نوع المحتوى الذي تريد إضافته',
          ),
          const SizedBox(height: 30),
          _buildAdTypeOption(
            icon: Icons.text_fields,
            title: 'إعلان نصي',
            subtitle: 'أضف نص مكتوب للإعلان',
            value: 'text',
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildAdTypeOption(
            icon: Icons.image,
            title: 'إعلان بصورة',
            subtitle: 'أضف صورة للإعلان',
            value: 'image',
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _buildAdTypeOption(
            icon: Icons.videocam,
            title: 'إعلان بفيديو',
            subtitle: 'أضف فيديو للإعلان',
            value: 'video',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildAdTypeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Color color,
  }) {
    final isSelected = _adType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _adType = value;
          _adDescription = null;
          _selectedFile = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenSelectionStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            icon: Icons.tv,
            title: 'اختيار الشاشات',
            subtitle: 'حدد الشاشات التي تريد عرض الإعلان عليها',
          ),
          const SizedBox(height: 20),
          if (_selectedScreens.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600]),
                  const SizedBox(width: 12),
                  Text(
                    'تم اختيار ${_selectedScreens.length} شاشة',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Expanded(
            child: _screens.isNotEmpty
                ? ListView.builder(
                    itemCount: _screens.length,
                    itemBuilder: (context, index) {
                      final screen = _screens[index];
                      return _buildScreenCard(screen);
                    },
                  )
                : _buildEmptyScreensState(),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenCard(Map<String, dynamic> screen) {
    final isSelected = _selectedScreens.contains(screen['id']);
    final screenName = screen['name'] ?? 'شاشة بدون اسم';
    final screenLocation = screen['location'] ?? 'موقع غير محدد';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedScreens.remove(screen['id']);
              } else {
                _selectedScreens.add(screen['id']);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        screenName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.blue[700] : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        screenLocation,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: Colors.blue[600], size: 24)
                else
                  Icon(Icons.circle_outlined, color: Colors.grey[400], size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyScreensState() {
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
            'لا توجد شاشات متاحة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم العثور على شاشات في ${widget.placeName}',
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
}