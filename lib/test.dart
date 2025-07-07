// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:image_picker/image_picker.dart';
//
// class AdminUploadAdScree extends StatefulWidget {
//   const AdminUploadAdScree({Key? key}) : super(key: key);
//
//   @override
//   State<AdminUploadAdScree> createState() => _AdminUploadAdScreeState();
// }
//
// class _AdminUploadAdScreeState extends State<AdminUploadAdScree> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseStorage _storage = FirebaseStorage.instance;
//   final ImagePicker _picker = ImagePicker();
//
//   bool _isLoading = false;
//   String? _adTitle;
//   String? _adDescription;
//   String _adType = 'text'; // 'text', 'image', 'video'
//   List<String> _screenIds = [];
//   List<String> _availableScreens = [];
//   File? _selectedFile;
//   Color? _backgroundColor;
//   bool _linkToAllScreens = true; // true: كل الشاشات، false: توزيع عادل
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchAvailableScreens();
//   }
//
//   Future<void> _fetchAvailableScreens() async {
//     try {
//       final snapshot = await _firestore.collection('screens').get();
//       final screens = snapshot.docs.map((doc) => doc.id).toList();
//       setState(() {
//         _availableScreens = screens;
//       });
//     } catch (e) {
//       print('Error fetching screens: $e');
//     }
//   }
//
//   Future<String?> _uploadFileToStorage(File file, String path) async {
//     try {
//       final ref = _storage.ref().child(path);
//       await ref.putFile(file);
//       return await ref.getDownloadURL();
//     } catch (e) {
//       print('Error uploading file: $e');
//       return null;
//     }
//   }
//
//   Future<void> _pickFile() async {
//     if (_adType == 'text') {
//       final controller = TextEditingController(text: _adDescription ?? '');
//       final result = await showDialog<String>(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: Text('اكتب محتوى الإعلان'),
//           content: TextField(
//             controller: controller,
//             maxLines: 4,
//             decoration: InputDecoration(hintText: 'اكتب النص هنا'),
//           ),
//           actions: [
//             TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
//             TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('تم')),
//           ],
//         ),
//       );
//
//       if (result != null && result.trim().isNotEmpty) {
//         setState(() {
//           _adDescription = result.trim();
//         });
//       }
//
//       return;
//     }
//
//     final pickedFile = _adType == 'image'
//         ? await _picker.pickImage(source: ImageSource.gallery)
//         : await _picker.pickVideo(source: ImageSource.gallery);
//
//     if (pickedFile != null) {
//       setState(() {
//         _selectedFile = File(pickedFile.path);
//       });
//     }
//   }
//
//   Future<void> uploadAd() async {
//     if (_screenIds.isEmpty) {
//       if (_availableScreens.isNotEmpty) {
//         if (_linkToAllScreens) {
//           _screenIds.addAll(_availableScreens);
//         } else {
//           // توزيع عادل
//           final adsSnapshot = await _firestore.collection('ads').get();
//           Map<String, int> screenAdCount = { for (var id in _availableScreens) id: 0 };
//           for (var ad in adsSnapshot.docs) {
//             List<dynamic>? adScreens = ad['screenIds'];
//             if (adScreens != null) {
//               for (var sid in adScreens) {
//                 if (screenAdCount.containsKey(sid)) {
//                   screenAdCount[sid] = screenAdCount[sid]! + 1;
//                 }
//               }
//             }
//           }
//           // ابحث عن الشاشة الأقل استخدامًا
//           String leastUsedScreen = screenAdCount.entries.reduce((a, b) => a.value < b.value ? a : b).key;
//           _screenIds.add(leastUsedScreen);
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('لا توجد شاشات متاحة لربط الإعلان')),
//         );
//         return;
//       }
//     }
//
//     if (_adType != 'text' && _selectedFile == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('يرجى اختيار ملف الإعلان')),
//       );
//       return;
//     }
//
//     setState(() {
//       _isLoading = true;
//     });
//
//     String? fileUrl;
//     if (_selectedFile != null) {
//       String fileName = 'ads/${DateTime.now().millisecondsSinceEpoch}.${_adType == 'video' ? 'mp4' : 'jpg'}';
//       fileUrl = await _uploadFileToStorage(_selectedFile!, fileName);
//     }
//
//     try {
//       await _firestore.collection('ads').add({
//         'title': _adTitle,
//         'description': _adDescription,
//         'type': _adType,
//         'fileUrl': fileUrl,
//         'screenIds': _screenIds,
//         'backgroundColor': _backgroundColor != null
//             ? '#${_backgroundColor!.value.toRadixString(16).padLeft(8, '0')}'
//             : null,
//         'created_at': FieldValue.serverTimestamp(),
//       });
//
//       setState(() {
//         _isLoading = false;
//         _selectedFile = null;
//         _screenIds = [];
//         _backgroundColor = null;
//         _adDescription = null;
//       });
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('تم رفع الإعلان بنجاح!')),
//       );
//     } catch (e) {
//       setState(() => _isLoading = false);
//       print('Error uploading ad: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('حدث خطأ أثناء رفع الإعلان')),
//       );
//     }
//   }
//
//   Widget _buildColorCircle(Color color) {
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           _backgroundColor = color;
//         });
//       },
//       child: Container(
//         margin: EdgeInsets.symmetric(horizontal: 4),
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           color: color,
//           border: Border.all(
//             color: _backgroundColor == color ? Colors.black : Colors.transparent,
//             width: 2,
//           ),
//         ),
//         width: 30,
//         height: 30,
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('🎯 رفع إعلان جديد')),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Card(
//           elevation: 4,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           child: Padding(
//             padding: const EdgeInsets.all(20.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text('تفاصيل الإعلان', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                 SizedBox(height: 10),
//                 TextField(
//                   decoration: InputDecoration(labelText: 'عنوان الإعلان'),
//                   onChanged: (value) => _adTitle = value,
//                 ),
//                 SizedBox(height: 10),
//                 TextField(
//                   decoration: InputDecoration(labelText: 'وصف الإعلان'),
//                   onChanged: (value) => _adDescription = value,
//                 ),
//                 SizedBox(height: 20),
//                 Row(
//                   children: [
//                     Text('نوع الإعلان: ', style: TextStyle(fontSize: 16)),
//                     SizedBox(width: 10),
//                     DropdownButton<String>(
//                       value: _adType,
//                       onChanged: (val) {
//                         setState(() {
//                           _adType = val!;
//                           _selectedFile = null;
//                         });
//                       },
//                       items: ['text', 'image', 'video'].map((type) {
//                         return DropdownMenuItem(
//                           value: type,
//                           child: Text(type == 'text' ? 'نص' : type == 'image' ? 'صورة' : 'فيديو'),
//                         );
//                       }).toList(),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 10),
//                 ElevatedButton.icon(
//                   onPressed: _pickFile,
//                   icon: Icon(Icons.upload_file),
//                   label: Text(_adType == 'text'
//                       ? 'اكتب محتوى الإعلان'
//                       : _adType == 'image'
//                       ? 'اختر صورة'
//                       : 'اختر فيديو'),
//                 ),
//                 if (_selectedFile != null || (_adType == 'text' && _adDescription != null))
//                   Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 8),
//                     child: Row(
//                       children: [
//                         Icon(Icons.check_circle, color: Colors.green),
//                         SizedBox(width: 8),
//                         Text('تم إدخال المحتوى'),
//                       ],
//                     ),
//                   ),
//                 if (_adType == 'text') ...[
//                   SizedBox(height: 15),
//                   Text('اختر لون الخلفية:', style: TextStyle(fontSize: 16)),
//                   Wrap(
//                     children: [
//                       _buildColorCircle(Colors.white),
//                       _buildColorCircle(Colors.black),
//                       _buildColorCircle(Colors.yellow),
//                       _buildColorCircle(Colors.blue),
//                       _buildColorCircle(Colors.green),
//                       _buildColorCircle(Colors.red),
//                     ],
//                   ),
//                 ],
//                 Divider(height: 30),
//                 Text('اختر الشاشات:', style: TextStyle(fontSize: 16)),
//                 SizedBox(height: 10),
//                 _availableScreens.isNotEmpty
//                     ? Wrap(
//                   spacing: 8,
//                   children: _availableScreens.map((screenId) {
//                     final selected = _screenIds.contains(screenId);
//                     return FilterChip(
//                       label: Text('شاشة $screenId'),
//                       selected: selected,
//                       onSelected: (val) {
//                         setState(() {
//                           if (val) {
//                             _screenIds.add(screenId);
//                           } else {
//                             _screenIds.remove(screenId);
//                           }
//                         });
//                       },
//                     );
//                   }).toList(),
//                 )
//                     : Center(child: CircularProgressIndicator()),
//                 SizedBox(height: 30),
//                 Row(
//                   children: [
//                     Text('طريقة الربط: ', style: TextStyle(fontSize: 16)),
//                     SizedBox(width: 10),
//                     Expanded(
//                       child: DropdownButton<bool>(
//                         value: _linkToAllScreens,
//                         onChanged: (val) {
//                           setState(() {
//                             _linkToAllScreens = val!;
//                           });
//                         },
//                         items: [
//                           DropdownMenuItem(
//                             value: true,
//                             child: Text('ربط تلقائي بكل الشاشات'),
//                           ),
//                           DropdownMenuItem(
//                             value: false,
//                             child: Text('توزيع عادل (أقل شاشة عليها إعلانات)'),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//                 if (_screenIds.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 8),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('الشاشات المرتبطة بهذا الإعلان:', style: TextStyle(fontWeight: FontWeight.bold)),
//                         Wrap(
//                           spacing: 8,
//                           children: _screenIds.map((id) => Chip(label: Text('شاشة $id'))).toList(),
//                         ),
//                       ],
//                     ),
//                   ),
//                 Center(
//                   child: ElevatedButton.icon(
//                     onPressed: _adTitle != null && _adDescription != null && !_isLoading
//                         ? uploadAd
//                         : null,
//                     icon: _isLoading ? CircularProgressIndicator(color: Colors.white) : Icon(Icons.cloud_upload),
//                     label: Text('رفع الإعلان'),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
//                       textStyle: TextStyle(fontSize: 16),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
