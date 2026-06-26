import 'package:dino/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

const seedColor = Color(0xFFFF9C29);

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Keep splash visible until HomePage is fully ready
    // ignore: lines_longer_than_80_chars
    Future.delayed(const Duration(milliseconds: 4500), FlutterNativeSplash.remove);
    
    return MaterialApp(
      home: const HomePage(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
      ),
    );
  }
}
