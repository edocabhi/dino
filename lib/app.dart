import 'package:dino/home_page.dart';
import 'package:flutter/material.dart';

const seedColor = Color(0xFFFF9C29);

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
