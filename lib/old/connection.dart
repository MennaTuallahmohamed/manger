// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/material.dart';
//
// class InternetStatusBanner extends StatefulWidget {
//   const InternetStatusBanner({Key? key}) : super(key: key);
//
//   @override
//   State<InternetStatusBanner> createState() => _InternetStatusBannerState();
// }
//
// class _InternetStatusBannerState extends State<InternetStatusBanner> {
//   bool _isConnected = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _checkConnection();
//     Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
//       setState(() {
//         _isConnected = result != ConnectivityResult.none;
//       });
//     });
//   }
//
//   Future<void> _checkConnection() async {
//     final result = await Connectivity().checkConnectivity();
//     setState(() {
//       _isConnected = result != ConnectivityResult.none;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isConnected) return SizedBox.shrink();
//
//     return Container(
//       width: double.infinity,
//       color: Colors.red,
//       padding: EdgeInsets.symmetric(vertical: 8),
//       child: Center(
//         child: Text(
//           'لا يوجد اتصال بالإنترنت',
//           style: TextStyle(color: Colors.white),
//         ),
//       ),
//     );
//   }
// }
