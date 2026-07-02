import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder snackIcon(IconData icon) {
  return find.descendant(
    of: find.byType(SnackBar),
    matching: find.byIcon(icon),
  );
}
