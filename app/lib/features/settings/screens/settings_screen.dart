// lib/features/settings/screens/settings_screen.dart
library;
/// Settings: hosts management, appearance, about (doc 06 §5).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connection/host_registry.dart';
import '../../../design/theme.dart';
import '../../../design/components/status_dot.dart';
import '../../pairing/providers/connection_providers.dart';
import '../providers/settings_providers.dart';
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  @override void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMachinesTab(),
          _buildAppearanceTab(),
          _buildAboutTab(),
        ],
      ),
    );
  }
  Widget _buildMachinesTab() {
    return ListView(
      children: [
        // Paired hosts list
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Machines', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PiColors.textSecondary)),
              const SizedBox(height: 8),
              // Active host
              _HostCard(
                name: "Hamish's MacBook",
                address: '192.168.1.20:8787',
                isActive: true,
                lastConnected: DateTime.now().subtract(const Duration(hours: 2)),
              ),
              // Inactive host (placeholder)
              _HostCard(
                name: 'Home Server',
                address: '192.168.1.30:8787',
                isActive: false,
                lastConnected: DateTime.now().subtract(const Duration(days: 3)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/pair'),
                icon: const Icon(Icons.add),
                label: const Text('Add Machine'),
              ),
            ],
          ),
        ),
        // Danger zone
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Danger', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PiColors.textSecondary)),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: PiColors.error),
                title: const Text('Forget this device'),
                subtitle: const Text('Wipes all pairing tokens and connections'),
                onTap: () => _showForgetConfirmation(context),
              ),
            ],
          ),
        ),
      ],
    );
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
              Text('Theme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PiColors.textSecondary)),
              const SizedBox(height: 8),
              _ThemeOption(
                label: 'System',
                icon: Icons.brightness_auto,
                value: ThemePreference.system,
                selected: _themePref(settings),
                onSelected: (v) => ref.read(settingsProvider.notifier).setTheme(
                      switch (v) {
                        ThemePreference.system => ThemePref.system,
                        ThemePreference.light => ThemePref.light,
                        ThemePreference.dark => ThemePref.dark,
                      },
                    ),
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
              Text('Chat text size', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PiColors.textSecondary)),
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A-Coder Mobile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Version 1.0.0 (build 1)', style: TextStyle(color: PiColors.textMuted)),
              const SizedBox(height: 24),
              _AboutRow(label: 'Protocol version', value: 'v1'),
              _AboutRow(label: 'WebSocket transport', value: 'ws://'),
              _AboutRow(label: 'Framework', value: 'Flutter 3.24+'),
              const SizedBox(height: 24),
              Text('Links', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PiColors.textSecondary)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.code_rounded),
                title: const Text('GitHub'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.article_rounded),
                title: const Text('Documentation'),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
  void _showForgetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forget this device?'),
        content: const Text('This will remove all pairing tokens and connections. You will need to re-pair.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              // Wipe tokens from secure storage, clear host metadata + active id.
              final registry = HostRegistry();
              for (final host in await registry.getHosts()) {
                await registry.removeHost(host.id);
              }
              if (!mounted) return;
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
  final String name;
  final String address;
  final bool isActive;
  final DateTime lastConnected;
  const _HostCard({required this.name, required this.address, required this.isActive, required this.lastConnected});
  @override Widget build(BuildContext context) {
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
                      Text(name, style: TextStyle(fontWeight: FontWeight.w600)),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: PiColors.accentSoft, borderRadius: BorderRadius.circular(4)),
                          child: Text('ACTIVE', style: TextStyle(fontSize: 9, fontFamily: 'JetBrains Mono', color: PiColors.accent)),
                        ),
                      ],
                    ],
                  ),
                  Text(address, style: const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono', color: PiColors.textMuted)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'test') ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection test: OK')));
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'test', child: Text('Test connection')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: PiColors.error))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
enum ThemePreference { system, dark, light }

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
  @override Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: value == selected ? Icon(Icons.check_rounded, color: PiColors.accent) : null,
      onTap: () => onSelected(value),
    );
  }
}
class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow({required this.label, required this.value});
  @override Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: PiColors.textSecondary)),
            Text(value, style: const TextStyle(fontFamily: 'JetBrains Mono', color: PiColors.textMuted)),
          ],
        ),
      );
}