import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'apps.dart';
import 'old/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Firebase.initializeApp(); // ✅ كده تمام بدون Options
  runApp(const MyApp());
  
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AdminScreen(),
    );
  }
}
