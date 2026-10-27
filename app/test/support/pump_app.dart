import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:acoder_mobile/app.dart';

/// Pump the real app shell. This touches secure storage / platform plugins,
/// so callers in pure widget tests should prefer isolated widget trees.
Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: ACoderApp()));
  await tester.pump();
}
