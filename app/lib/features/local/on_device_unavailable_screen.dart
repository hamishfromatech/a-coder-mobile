// Reachable-but-disabled replacement for the `/local*` routes on platforms
// without a `llamadart` native runtime (iOS in v1 — see THE-110).
//
// It deliberately imports nothing from the local chat or model-hub code, so an
// iOS route resolution cannot construct `LocalModelsScreen`/`LocalChatScreen`
// or reach a `llamadart` call.

import 'package:flutter/material.dart';

import '../../design/components/empty_state.dart';
import 'on_device_availability.dart';

class OnDeviceUnavailableScreen extends StatelessWidget {
  const OnDeviceUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On-device')),
      body: const EmptyState(
        icon: Icons.memory_outlined,
        title: onDeviceUnavailableTitle,
        hint: onDeviceUnavailableHint,
      ),
    );
  }
}
