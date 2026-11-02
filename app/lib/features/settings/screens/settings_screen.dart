// lib/features/settings/screens/settings_screen.dart
/// Settings: hosts management, appearance, about (doc 06 §5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connection/host_registry.dart';
import '../../../design/primitives.dart';
import '../../../design/components/button.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../design/components/kit.dart';
import '../../../design/skins.dart';
import '../../../design/theme.dart';
import '../../../design/components/status_dot.dart';
import '../../pairing/providers/connection_providers.dart';
import '../../chat/providers/chat_providers.dart';
import '../../pairing/providers/pairing_providers.dart';
import '../../sessions/providers/session_pins.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, bool> _testingHosts = {};
  final Map<String, String?> _testResults = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.computer_rounded), text: 'Machines'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'Session'),
            Tab(icon: Icon(Icons.notifications_outlined), text: 'Alerts'),
            Tab(icon: Icon(Icons.palette_rounded), text: 'Appearance'),
            Tab(icon: Icon(Icons.tips_and_updates_outlined), text: 'Advanced'),
            Tab(icon: Icon(Icons.info_outline_rounded), text: 'About'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMachinesTab(context),
          _buildSessionTab(context),
          _buildAlertsTab(context),
          _buildAppearanceTab(),
          _buildAdvancedTab(context),
          _buildAboutTab(),
        ],
      ),
    );
  }

  Widget _buildMachinesTab(BuildContext context) {
    final hosts = ref.watch(hostsProvider);
    final activeId = ref.watch(activeHostIdProvider).valueOrNull;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Machines',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PiColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (hosts.isEmpty)
                const ListTile(
                  leading: Icon(Icons.cloud_off_rounded),
                  title: Text('No paired machines'),
                  subtitle: Text('Add a machine to get started'),
                ),
              for (final host in hosts)
                _HostCard(
                  host: host,
                  isActive: host.id == activeId,
                  testing: _testingHosts[host.id] == true,
                  testResult: _testResults[host.id],
                  onMakeActive: () async {
                    await ref.read(hostsProvider.notifier).setActive(host.id);
                    ref.invalidate(activeHostIdProvider);
                    ref.invalidate(activeHostProvider);
                  },
                  onTest: () => _testConnection(host),
                  onRemove: () => _confirmRemove(host),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/pair'),
                icon: const Icon(Icons.add),
                label: const Text('Add Machine'),
              ),
              const SizedBox(height: 24),
              Text(
                'Danger',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PiColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading:
                    Icon(Icons.warning_amber_rounded, color: PiColors.error),
                title: const Text('Forget this device'),
                subtitle:
                    const Text('Wipes all pairing tokens and connections'),
                onTap: _showForgetConfirmation,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _testConnection(PairedHost host) async {
    if (!mounted) return;
    setState(() {
      _testingHosts[host.id] = true;
      _testResults[host.id] = null;
    });
    String? result;
    try {
      final registry = HostRegistry();
      final token = await registry.getToken(host.id);
      if (token == null || token.isEmpty) {
        result = 'Failed: no pairing token';
      } else {
        result = 'OK — credentials present';
      }
    } catch (e) {
      result = 'Failed: $e';
    }
    if (!mounted) return;
    setState(() {
      _testingHosts[host.id] = false;
      _testResults[host.id] = result;
    });
  }

  Future<void> _confirmRemove(PairedHost host) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${host.name}?'),
        content: const Text(
            'This only revokes local pairing. The desktop keeps its token.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: PiColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(hostsProvider.notifier).removeHost(host.id);
    ref.invalidate(activeHostIdProvider);
    ref.invalidate(activeHostProvider);
  }

  /// Desktop parity: model · thinking · permission mode live in Settings, not
  /// only in the chat overflow, so defaults are discoverable.
  Widget _buildSessionTab(BuildContext context) {
    final hostId = ref.watch(activeHostIdProvider).valueOrNull;
    final chat = ref.watch(chatStateProvider);
    final session = chat.session;
    final connected = hostId != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('MODEL'),
        const SizedBox(height: 8),
        InkWell(
          onTap: hostId == null
              ? null
              : () => Navigator.of(context)
                  .pushNamed('/model', arguments: {'hostId': hostId}),
          borderRadius: BorderRadius.circular(PiRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PiColors.surfaceRaised,
              borderRadius: BorderRadius.circular(PiRadius.lg),
              border: Border.all(color: PiColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.modelName.isNotEmpty
                            ? session.modelName
                            : (session.model.isNotEmpty
                                ? session.model
                                : 'No model selected'),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: PiColors.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (session.modelProvider.isNotEmpty)
                        Text(
                          '${session.modelProvider} · ${session.model}',
                          style: TextStyle(
                              fontSize: 10,
                              fontFamily: PiFonts.mono,
                              color: PiColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: PiColors.textFaint),
              ],
            ),
          ),
        ),
        const Divider(height: 28),
        _sectionLabel('THINKING LEVEL'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final level in const [
              'off',
              'minimal',
              'low',
              'medium',
              'high'
            ])
              _ChoiceChip(
                label: level,
                selected: session.thinkingLevel == level,
                enabled: connected,
                onTap: () => ref
                    .read(sessionControllerProvider(hostId!).notifier)
                    .setThinkingLevel(level),
              ),
          ],
        ),
        const Divider(height: 28),
        _sectionLabel('PERMISSION MODE'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mode in const ['default', 'plan', 'auto'])
              _ChoiceChip(
                label: mode,
                selected: session.permissionMode == mode,
                enabled: connected,
                onTap: () => ref
                    .read(sessionControllerProvider(hostId!).notifier)
                    .setPermissionMode(mode),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          connected
              ? 'Defaults apply to the active session; the desktop shows the '
                  'same controls in its session actions.'
              : 'Pair a host to change session defaults.',
          style: TextStyle(fontSize: 11, color: PiColors.textMuted),
        ),
      ],
    );
  }

  /// Local alerts (desktop "attention" parity). Background delivery while the
  /// app is suspended needs the push relay, which is not implemented yet.
  Widget _buildAlertsTab(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final master = settings.notificationsEnabled;

    Future<void> setMaster(bool value) async {
      if (!value) {
        await ref
            .read(settingsProvider.notifier)
            .setNotificationsEnabled(false);
        return;
      }
      final granted = await NotificationService.instance.requestPermission();
      await ref
          .read(settingsProvider.notifier)
          .setNotificationsEnabled(granted);
      if (!granted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Notifications are blocked — enable them in system settings.')));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('ALERTS'),
        const SizedBox(height: 4),
        _toggleRow(
          title: 'Notifications',
          subtitle: 'Approvals, finished turns, failing tasks',
          value: master,
          enabled: true,
          onChanged: setMaster,
        ),
        const Divider(height: 20),
        _toggleRow(
          title: 'Approvals needed',
          subtitle: 'The agent is blocked waiting for permission',
          value: settings.alertApprovals,
          enabled: master,
          onChanged: (v) =>
              ref.read(settingsProvider.notifier).setAlertApprovals(v),
        ),
        _toggleRow(
          title: 'Turn finished',
          subtitle: 'The agent finished while you were away',
          value: settings.alertTurnFinished,
          enabled: master,
          onChanged: (v) =>
              ref.read(settingsProvider.notifier).setAlertTurnFinished(v),
        ),
        _toggleRow(
          title: 'Background sessions',
          subtitle: 'A detached session is waiting for input',
          value: settings.alertBackgroundWaiting,
          enabled: master,
          onChanged: (v) =>
              ref.read(settingsProvider.notifier).setAlertBackgroundWaiting(v),
        ),
        _toggleRow(
          title: 'Scheduled task failures',
          subtitle: 'A routine failed on its last run',
          value: settings.alertCronFailures,
          enabled: master,
          onChanged: (v) =>
              ref.read(settingsProvider.notifier).setAlertCronFailures(v),
        ),
        const Divider(height: 20),
        _toggleRow(
          title: 'Also while the app is open',
          subtitle: 'Off by default — you can already see the screen',
          value: settings.alertWhileForeground,
          enabled: master,
          onChanged: (v) =>
              ref.read(settingsProvider.notifier).setAlertWhileForeground(v),
        ),
        const SizedBox(height: 14),
        Text(
          'Alerts are raised locally while the app is running (foreground or '
          'backgrounded with the connection alive). Being paged when the app '
          'is fully suspended needs a push relay, which is not implemented yet.',
          style:
              TextStyle(fontSize: 11, height: 1.5, color: PiColors.textMuted),
        ),
        const SizedBox(height: 10),
        PiButton(
          label: 'Re-check permission',
          variant: PiButtonVariant.outline,
          size: PiButtonSize.sm,
          icon: Icons.notifications_active_outlined,
          onPressed: () async {
            final granted =
                await NotificationService.instance.requestPermission();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(granted
                      ? 'Notifications are allowed.'
                      : 'Notifications are still blocked.')));
            }
          },
        ),
      ],
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: PiColors.text)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 11, color: PiColors.textMuted)),
                ],
              ),
            ),
            PiSwitch(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedTab(BuildContext context) {
    final pins = ref.watch(sessionPinsProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('DIAGNOSTICS'),
        const SizedBox(height: 8),
        const _AboutRow(label: 'Protocol version', value: 'v1'),
        const _AboutRow(label: 'Transport', value: 'WebSocket + JSONL'),
        _AboutRow(label: 'Pinned sessions', value: '${pins.length}'),
        const SizedBox(height: 12),
        Text(
          'Engine and app versions are shown on the connection sheet and in '
          'About.',
          style: TextStyle(fontSize: 11, color: PiColors.textMuted),
        ),
        const Divider(height: 28),
        _sectionLabel('LOCAL DATA'),
        const SizedBox(height: 4),
        Text(
          'Pins, drafts, skins and preferences live on this phone. Clearing '
          'them does not touch the host.',
          style: TextStyle(fontSize: 11, color: PiColors.textMuted),
        ),
        const SizedBox(height: 10),
        PiButton(
          label: 'Clear pinned sessions (${pins.length})',
          variant: PiButtonVariant.outline,
          size: PiButtonSize.sm,
          icon: Icons.push_pin_outlined,
          onPressed: pins.isEmpty
              ? null
              : () async {
                  for (final path in pins.toList()) {
                    await ref.read(sessionPinsProvider.notifier).toggle(path);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pins cleared')));
                  }
                },
        ),
        const SizedBox(height: 8),
        PiButton(
          label: 'Reset appearance to Aurora',
          variant: PiButtonVariant.outline,
          size: PiButtonSize.sm,
          icon: Icons.restart_alt,
          onPressed: () =>
              ref.read(settingsProvider.notifier).setSkin(defaultSkinName),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontFamily: PiFonts.mono,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: PiColors.textFaint,
        ),
      );

  Widget _buildAppearanceTab() {
    final settings = ref.watch(settingsProvider);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SKIN',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: PiColors.textSecondary)),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final meta in piSkinList)
                        _SkinOption(
                          meta: meta,
                          palette: resolveSkinPalette(meta.name, isDark),
                          selected: settings.skin == meta.name,
                          onTap: () => ref
                              .read(settingsProvider.notifier)
                              .setSkin(meta.name),
                        ),
                    ],
                  );
                },
              ),
              const Divider(height: 32),
              Text('THEME',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: PiColors.textSecondary)),
              const SizedBox(height: 8),
              _ThemeOption(
                label: 'System',
                icon: Icons.brightness_auto,
                value: ThemePreference.system,
                selected: _themePref(settings),
                onSelected: (v) => ref
                    .read(settingsProvider.notifier)
                    .setTheme(ThemePref.system),
              ),
              _ThemeOption(
                label: 'Dark',
                icon: Icons.dark_mode,
                value: ThemePreference.dark,
                selected: _themePref(settings),
                onSelected: (v) => ref
                    .read(settingsProvider.notifier)
                    .setTheme(ThemePref.dark),
              ),
              _ThemeOption(
                label: 'Light',
                icon: Icons.light_mode,
                value: ThemePreference.light,
                selected: _themePref(settings),
                onSelected: (v) => ref
                    .read(settingsProvider.notifier)
                    .setTheme(ThemePref.light),
              ),
              const Divider(height: 32),
              Text('CHAT TEXT SIZE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: PiColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('13', style: TextStyle(color: PiColors.textMuted)),
                  Expanded(
                    child: Slider(
                      value: settings.chatTextSize,
                      min: 13,
                      max: 17,
                      divisions: 8,
                      label: '${settings.chatTextSize.round()}sp',
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .setChatTextSize(v),
                    ),
                  ),
                  Text('17', style: TextStyle(color: PiColors.textMuted)),
                ],
              ),
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chat backdrop',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: PiColors.text)),
                          const SizedBox(height: 2),
                          Text('Faint texture behind the transcript',
                              style: TextStyle(
                                  fontSize: 11, color: PiColors.textMuted)),
                        ],
                      ),
                    ),
                    PiSwitch(
                      value: settings.chatBackdrop,
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .setChatBackdrop(v),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Haptic feedback',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: PiColors.text)),
                          const SizedBox(height: 2),
                          Text('Vibrate on send and approvals',
                              style: TextStyle(
                                  fontSize: 11, color: PiColors.textMuted)),
                        ],
                      ),
                    ),
                    PiSwitch(
                      value: settings.haptics,
                      onChanged: (v) =>
                          ref.read(settingsProvider.notifier).setHaptics(v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ThemePreference _themePref(AppSettings settings) => switch (settings.theme) {
        ThemePref.system => ThemePreference.system,
        ThemePref.dark => ThemePreference.dark,
        ThemePref.light => ThemePreference.light,
      };

  Widget _buildAboutTab() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A-Coder Mobile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Version 1.0.0 (build 1)',
                  style: TextStyle(color: PiColors.textMuted)),
              const SizedBox(height: 24),
              const _AboutRow(label: 'Protocol version', value: 'v1'),
              const _AboutRow(label: 'WebSocket transport', value: 'ws://'),
              const _AboutRow(label: 'Framework', value: 'Flutter 3.24+'),
              const SizedBox(height: 24),
              Text('LINKS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: PiColors.textSecondary)),
              const SizedBox(height: 8),
              const ListTile(
                leading: Icon(Icons.code_rounded),
                title: Text('GitHub'),
              ),
              const ListTile(
                leading: Icon(Icons.article_rounded),
                title: Text('Documentation'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showForgetConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forget this device?'),
        content: const Text(
            'This will remove all pairing tokens and connections. You will need to re-pair.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final registry = HostRegistry();
              for (final host in await registry.getHosts()) {
                await registry.removeHost(host.id);
              }
              if (!mounted || !context.mounted) return;
              ref.invalidate(activeHostIdProvider);
              ref.invalidate(activeHostProvider);
              Navigator.of(context).pushReplacementNamed('/pair');
            },
            style: ElevatedButton.styleFrom(backgroundColor: PiColors.error),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  final PairedHost host;
  final bool isActive;
  final bool testing;
  final String? testResult;
  final VoidCallback onMakeActive;
  final VoidCallback onTest;
  final VoidCallback onRemove;

  const _HostCard({
    required this.host,
    required this.isActive,
    required this.testing,
    required this.testResult,
    required this.onMakeActive,
    required this.onTest,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? PiColors.accentSoft : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PiColors.border),
        ),
        child: Row(
          children: [
            StatusDot(type: isActive ? StatusDotType.live : StatusDotType.idle),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(host.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                              color: PiColors.accentSoft,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('ACTIVE',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontFamily: PiFonts.mono,
                                  color: PiColors.accent)),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(host.address,
                            style: TextStyle(
                                fontSize: 12,
                                fontFamily: PiFonts.mono,
                                color: PiColors.textMuted)),
                      ),
                      if (host.tls) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_outline,
                            size: 12, color: PiColors.success),
                        const SizedBox(width: 2),
                        Text(
                          host.certFingerprint != null ? 'TLS pinned' : 'TLS',
                          style: TextStyle(
                              fontSize: 10,
                              fontFamily: PiFonts.mono,
                              color: PiColors.success),
                        ),
                      ],
                    ],
                  ),
                  if (testResult != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        testResult!,
                        style: TextStyle(
                          fontSize: 11,
                          color: testResult!.startsWith('OK')
                              ? PiColors.success
                              : PiColors.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (testing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Semantics(
                label: 'Machine actions menu',
                child: PopupMenuButton<String>(
                  tooltip: 'Machine actions',
                  onSelected: (val) {
                    if (val == 'test') onTest();
                    if (val == 'active') onMakeActive();
                    if (val == 'remove') onRemove();
                  },
                  itemBuilder: (_) => [
                    if (!isActive)
                      const PopupMenuItem(
                          value: 'active', child: Text('Set active')),
                    const PopupMenuItem(
                        value: 'test', child: Text('Test connection')),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove',
                            style: TextStyle(color: PiColors.error))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final ThemePreference value;
  final ThemePreference selected;
  final ValueChanged<ThemePreference> onSelected;
  final IconData icon;
  final String label;
  const _ThemeOption({
    required this.value,
    required this.selected,
    required this.onSelected,
    required this.icon,
    required this.label,
  });
  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Semantics(
      label: '$label theme',
      button: true,
      selected: isSelected,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: isSelected
            ? Icon(Icons.check_rounded, color: PiColors.accent)
            : null,
        onTap: () => onSelected(value),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: PiColors.textSecondary)),
            Text(value,
                style: TextStyle(
                    fontFamily: PiFonts.mono, color: PiColors.textMuted)),
          ],
        ),
      );
}

/// Desktop parity choice chip (thinking level, permission mode).
class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(PiRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? PiColors.accentSoft : PiColors.surfaceRaised,
            borderRadius: BorderRadius.circular(PiRadius.md),
            border: Border.all(
              color: selected
                  ? PiColors.accent.withValues(alpha: 0.5)
                  : PiColors.border,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontFamily: PiFonts.mono,
              letterSpacing: 0.5,
              color: selected ? PiColors.accent : PiColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop skin swatch card (Appearance → Skin).
class _SkinOption extends StatelessWidget {
  final PiSkinMeta meta;
  final PiSkinPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _SkinOption({
    required this.meta,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final swatches = [
      palette.bg,
      palette.surfaceRaised,
      palette.accent,
      palette.text,
    ];
    return Semantics(
      selected: selected,
      button: true,
      label: meta.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PiRadius.xl),
        child: Container(
          width: 152,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: palette.surfaceRaised.toColor,
            borderRadius: BorderRadius.circular(PiRadius.xl),
            border: Border.all(
              color: selected ? palette.accent.toColor : PiColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final hex in swatches)
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: hex.toColor,
                        borderRadius: BorderRadius.circular(PiRadius.sm),
                        border: Border.all(
                          color: palette.text.toColor.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meta.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.text.toColor,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle,
                        size: 14, color: palette.accent.toColor),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                meta.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  color: palette.textMuted.toColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ThemePreference { system, dark, light }

extension _HostAddress on PairedHost {
  String get address => '$host:$port';
}
