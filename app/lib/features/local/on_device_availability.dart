// Platform gate for the on-device LFM3 surface (THE-110).
//
// `app/pubspec.yaml` configures the `llamadart` native backends for
// `android-arm64` and `android-x64` only, so an iOS build has no native
// runtime to load. The board scoped v1 to Android on 2026-11-19: iOS ships
// pairing + chat, and every on-device entry point is gated here.
//
// `defaultTargetPlatform` (rather than `Platform.isAndroid`) is used so widget
// tests can drive both paths with `debugDefaultTargetPlatformOverride` while
// production behaviour stays the same: Android true, iOS false.

import 'package:flutter/foundation.dart';

const String onDeviceUnavailableTitle =
    'On-device models are Android-only in v1';

const String onDeviceUnavailableHint =
    'This iOS build pairs with a desktop A-Coder host for chat. '
    'Local LFM3 models need the Android native runtime.';

/// True only on Android, the one platform that ships a `llamadart` backend in
/// v1. Pass [platform] in tests to check the mapping without global overrides.
bool onDeviceModelsAvailable([TargetPlatform? platform]) {
  if (kIsWeb) return false;
  return (platform ?? defaultTargetPlatform) == TargetPlatform.android;
}
