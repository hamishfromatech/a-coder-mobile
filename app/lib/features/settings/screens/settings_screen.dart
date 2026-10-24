// lib/features/settings/screens/settings_screen.dart
/// Settings: hosts management, appearance, about (doc 06 §5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connection/host_registry.dart';
import '../../../design/theme.dart';
import '../../../design/components/status_dot.dart';
import '../../pairing/providers/connection_providers.dart';
import '../../pairing/providers/pairing_providers.dart';
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
    _tabController = TabController(length: 3, vsync: this);
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
          tabs: const [
            Tab(icon: Icon(Icons.computer_rounded), text: 'Machines'),
            Tab(icon: Icon(Icons.palette_rounded), text: 'Appearance'),
            Tab(icon: Icon(Icons.info_outline_rounded), text: 'About'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMachinesTab(context),
          _buildAppearanceTab(),
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
              const Text(
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
              const Text(
                'Danger',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PiColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: PiColors.error),
                title: const Text('Forget this device'),
                subtitle: const Text('Wipes all pairing tokens and connections'),
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
        content: const Text('This only revokes local pairing. The desktop keeps its token.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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

  Widget _buildAppearanceTab() {
    final settings = ref.watch(settingsProvider);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('THEME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: PiColors.textSecondary)),
              const SizedBox(height: 8),
              _ThemeOption(
                label: 'System',
                icon: Icons.brightness_auto,
                value: ThemePreference.system,
                selected: _themePref(settings),
                onSelected: (v) => ref.read(settingsProvider.notifier).setTheme(ThemePref.system),
              ),
              _ThemeOption(
                label: 'Dark',
                icon: Icons.dark_mode,
                value: ThemePreference.dark,
                selected: _themePref(settings),
                onSelected: (v) => ref.read(settingsProvider.notifier).setTheme(ThemePref.dark),
              ),
              _ThemeOption(
                label: 'Light',
                icon: Icons.light_mode,
                value: ThemePreference.light,
                selected: _themePref(settings),
                onSelected: (v) => ref.read(settingsProvider.notifier).setTheme(ThemePref.light),
              ),
              const Divider(height: 32),
              const Text('CHAT TEXT SIZE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: PiColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('13', style: TextStyle(color: PiColors.textMuted)),
                  Expanded(
                    child: Slider(
                      value: settings.chatTextSize,
                      min: 13,
                      max: 17,
                      divisions: 8,
                      label: '${settings.chatTextSize.round()}sp',
                      onChanged: (v) => ref.read(settingsProvider.notifier).setChatTextSize(v),
                    ),
                  ),
                  const Text('17', style: TextStyle(color: PiColors.textMuted)),
                ],
              ),
              const Divider(height: 32),
              SwitchListTile(
                title: const Text('Haptic feedback'),
                subtitle: const Text('Vibrate on send and approvals'),
                value: settings.haptics,
                onChanged: (v) => ref.read(settingsProvider.notifier).setHaptics(v),
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
        const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A-Coder Mobile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Version 1.0.0 (build 1)', style: TextStyle(color: PiColors.textMuted)),
              SizedBox(height: 24),
              _AboutRow(label: 'Protocol version', value: 'v1'),
              _AboutRow(label: 'WebSocket transport', value: 'ws://'),
              _AboutRow(label: 'Framework', value: 'Flutter 3.24+'),
              SizedBox(height: 24),
              Text('LINKS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: PiColors.textSecondary)),
              SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.code_rounded),
                title: Text('GitHub'),
              ),
              ListTile(
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
        content: const Text('This will remove all pairing tokens and connections. You will need to re-pair.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
                        child: Text(host.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: PiColors.accentSoft, borderRadius: BorderRadius.circular(4)),
                          child: const Text('ACTIVE', style: TextStyle(fontSize: 9, fontFamily: 'JetBrains Mono', color: PiColors.accent)),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(host.address,
                            style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'JetBrains Mono',
                                color: PiColors.textMuted)),
                      ),
                      if (host.tls) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.lock_outline,
                            size: 12, color: PiColors.success),
                        const SizedBox(width: 2),
                        Text(
                          host.certFingerprint != null ? 'TLS pinned' : 'TLS',
                          style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'JetBrains Mono',
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
                          color: testResult!.startsWith('OK') ? PiColors.success : PiColors.error,
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
                    if (!isActive) const PopupMenuItem(value: 'active', child: Text('Set active')),
                    const PopupMenuItem(value: 'test', child: Text('Test connection')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: PiColors.error))),
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
        trailing: isSelected ? const Icon(Icons.check_rounded, color: PiColors.accent) : null,
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
            Text(label, style: const TextStyle(color: PiColors.textSecondary)),
            Text(value, style: const TextStyle(fontFamily: 'JetBrains Mono', color: PiColors.textMuted)),
          ],
        ),
      );
}

enum ThemePreference { system, dark, light }

extension _HostAddress on PairedHost {
  String get address => '$host:$port';
}
