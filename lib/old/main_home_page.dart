// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:khaled_admin/add_advertise_page.dart';
// import 'package:khaled_admin/add_screen_page.dart';
// import 'package:khaled_admin/home_page.dart';
// import 'package:khaled_admin/test.dart';
//
// class MainHomePage extends StatefulWidget {
//   const MainHomePage({super.key});
//
//   @override
//   State<MainHomePage> createState() => _MainHomePageState();
// }
//
// class _MainHomePageState extends State<MainHomePage> {
//   int _selectedIndex = 0;
//
//   final List<Widget> _screens = [HomeCategory(),
//     AddScreenPage(),
//     AdminUploadAdScree()  ];
//
//
//   void _onItemTapped(int index) {
//     setState(() {
//       _selectedIndex = index;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: _screens[_selectedIndex],
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _selectedIndex,
//         onTap: _onItemTapped,
//         items: const [
//           BottomNavigationBarItem(
//             icon: Icon(Icons.home),
//             label: 'الرئيسية',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.category),
//             label: 'اضافه شاشه',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.settings),
//             label: 'اضافه اعلان  ',
//           ),
//         ],
//       ),
//     );
//   }
// }
