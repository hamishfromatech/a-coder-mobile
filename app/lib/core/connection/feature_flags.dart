// lib/core/connection/feature_flags.dart

library;

/// Feature flags — single source of truth for optional features (doc 05 §10).
/// Default all off except the shipped set.

class FeatureFlags {
  // M6 extensions
  static const bool enableCron = false;
  static const bool enableOffice = false;

  // Deferred (N2) — file browsing/editing UI
  static const bool enableFiles = false;

  // Deferred (N4) — push notifications
  static const bool enablePush = false;

  // Always on for v1
  static const bool enableChat = true;
  static const bool enableSessions = true;
  static const bool enableApprovals = true;
}
