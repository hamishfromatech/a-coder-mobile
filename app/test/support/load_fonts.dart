// Deterministic UI fonts for golden tests.
//
// Flutter's test runner uses the Ahem font by default, which paints every
// glyph as a box — goldens then verify layout but not the actual type.
// Load the SDK's Roboto + MaterialIcons so goldens show real text and icons.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadUiFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.isEmpty) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  if (!Directory(dir).existsSync()) return;

  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    var added = false;
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      loader.addFont(
        Future<ByteData>.value(
          ByteData.sublistView(Uint8List.fromList(file.readAsBytesSync())),
        ),
      );
      added = true;
    }
    if (added) await loader.load();
  }

  await load('Roboto', [
    '$dir/Roboto-Regular.ttf',
    '$dir/Roboto-Medium.ttf',
    '$dir/Roboto-Bold.ttf',
  ]);
  await load('MaterialIcons', ['$dir/MaterialIcons-Regular.otf']);

  // The app bundles JetBrains Mono for code/args; load the same files the
  // runtime uses so code blocks are real glyphs in goldens too.
  final jb = Directory('assets/fonts');
  if (jb.existsSync()) {
    await load('JetBrains Mono', [
      'assets/fonts/JetBrainsMono-Regular.ttf',
      'assets/fonts/JetBrainsMono-Bold.ttf',
    ]);
  }
}
