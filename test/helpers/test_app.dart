import 'package:flutter/material.dart';
import 'package:tailg_ble_app/widgets/void_particles.dart';
import 'package:tailg_ble_app/widgets/void_typography.dart';

class TestApp extends StatelessWidget {
  final Widget home;

  const TestApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    VoidParticleField.enableAnimation = false;
    KineticType.enableAnimation = false;
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: InkRipple.splashFactory,
      ),
      home: home,
    );
  }
}
