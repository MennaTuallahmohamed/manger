// import 'package:flutter/material.dart';
//
// import 'add_client.dart';
// import 'add_screen_page.dart';
//
// class HomeScreen extends StatelessWidget {
//   const HomeScreen({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('لوحة التحكم'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.exit_to_app),
//             onPressed: () {
//               // هنا هتضيف الكود الخاص بتسجيل الخروج
//               // مثلا FirebaseAuth.instance.signOut();
//             },
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'مرحبًا بك في لوحة التحكم',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 20),
//             Text(
//               'اختر من الخيارات التالية:',
//               style: TextStyle(fontSize: 18),
//             ),
//             SizedBox(height: 20),
//             // قائمة الأزرار
//             ListView(
//               shrinkWrap: true,
//               children: [
//                 _buildDashboardButton(
//                   context,
//                   title: 'إضافة عميل',
//                   onPressed: () {
//                     // لو ضغط على الزر ده هيروح على شاشة إضافة العميل
//                     Navigator.push(context, MaterialPageRoute(builder: (context) => AddClientScreen(),));
//                   },
//                 ),
//                 _buildDashboardButton(
//                   context,
//                   title: 'إضافة شاشة لعميل',
//                   onPressed: () {
//                     // هنا نحتاج إلى تحديد clientId
//                     String clientId = "your_client_id";  // هنا يجب أن تأتي من قاعدة بيانات أو اختيار من قائمة العملاء
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => AddScreenToClientScreen(clientId: clientId),  // تمرير clientId
//                       ),
//                     );
//                   },
//                 ),
//                 _buildDashboardButton(
//                   context,
//                   title: 'رفع إعلان',
//                   onPressed: () {
//
//                     Navigator.pushNamed(context, '/uploadAd');
//                   },
//                 ),
//                 _buildDashboardButton(
//                   context,
//                   title: 'عرض العملاء والشاشات',
//                   onPressed: () {
//                     // لو ضغط على الزر ده هيروح على شاشة عرض العملاء والشاشات
//                     Navigator.pushNamed(context, '/viewClients');
//                   },
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // دالة لبناء زر داخل لوحة التحكم
//   Widget _buildDashboardButton(
//       BuildContext context, {
//         required String title,
//         required VoidCallback onPressed,
//       }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: ElevatedButton(
//         onPressed: onPressed,
//         style: ElevatedButton.styleFrom(
//           padding: EdgeInsets.symmetric(vertical: 15),
//           minimumSize: Size(double.infinity, 50),
//         ),
//         child: Text(title, style: TextStyle(fontSize: 18)),
//       ),
//     );
//   }
// }
