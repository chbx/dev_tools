import 'dart:io';

import 'package:flutter/material.dart';
import 'package:macos_window_utils/window_manipulator.dart';

import 'features/home/home.dart';

void main() async {
  await init();
  runApp(const MyApp());
}

Future<void> init() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isMacOS) {
    await WindowManipulator.initialize();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Scaffold(body: const MyHomePage()),
    );
  }
}
