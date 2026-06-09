import 'package:flutter/material.dart';

class TestApp extends StatelessWidget {
  final Widget home;

  const TestApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: InkRipple.splashFactory,
      ),
      home: home,
    );
  }
}
