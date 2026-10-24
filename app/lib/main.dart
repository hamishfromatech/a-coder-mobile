// lib/main.dart
library;
/// Entry point — bootstraps Riverpod and runs the app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  runApp(const ProviderScope(child: ACoderApp()));
}
