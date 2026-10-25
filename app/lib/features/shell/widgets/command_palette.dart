// Command palette — the mobile take on the desktop's ⌘K launcher.
//
// One search field, then grouped actions and recent sessions. Actions reuse
// the existing named routes so the palette never owns navigation state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protocol/responses.dart' show RpcSessionInfo;
import '../../../design/components/kit2.dart';
import '../../../design/primitives.dart';
import '../../../design/theme.dart';
import '../../pairing/providers/connection_providers.dart';
import '../../sessions/providers/sessions_providers.dart';
import '../../settings/providers/settings_providers.dart';

Future<void> showPiCommandPalette(
  BuildContext context,
  WidgetRef ref, {
  required String hostId,
}) {
  return showPiModal<void>(
    context,
    maxWidth: 520,
    builder: (_) => _CommandPalette(hostId: hostId),
  );
}

class _PaletteAction {
  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback run;
  const _PaletteAction(this.icon, this.label, this.run, {this.hint});
}

class _CommandPalette extends ConsumerStatefulWidget {
  final String hostId;
  const _CommandPalette({required this.hostId});

  @override
  ConsumerState<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<_CommandPalette> {
  String _query = '';

  bool _matches(String text) =>
      _query.isEmpty || text.toLowerCase().contains(_query.toLowerCase());

  void _close([Object? result]) => Navigator.of(context).pop(result);

  void _go(String route, [Map<String, String>? args]) {
    _close();
    Navigator.of(context).pushNamed(route, arguments: args);
  }

  List<_PaletteAction> _actions() {
    final settings = ref.read(settingsProvider.notifier);
    return [
      _PaletteAction(
        Icons.add_comment_outlined,
        'New session',
        () async {
          _close();
          try {
            await ref
                .read(sessionControllerProvider(widget.hostId).notifier)
                .newSession();
          } catch (_) {
            // Offline: the home screen banner explains the state.
          }
        },
        hint: 'new',
      ),
      _PaletteAction(
        Icons.tune,
        'Switch model',
        () => _go('/model', {'hostId': widget.hostId}),
        hint: 'model',
      ),
      _PaletteAction(
        Icons.schedule_outlined,
        'Scheduled tasks',
        () => _go('/cron', {'hostId': widget.hostId}),
        hint: 'cron',
      ),
      _PaletteAction(
        Icons.groups_outlined,
        'Your Office',
        () => _go('/office', {'hostId': widget.hostId}),
        hint: 'office',
      ),
      _PaletteAction(
        Icons.settings_outlined,
        'Settings',
        () => _go('/settings'),
        hint: 'settings',
      ),
      _PaletteAction(
        Icons.palette_outlined,
        'Appearance & skins',
        () => _go('/settings'),
        hint: 'theme',
      ),
      _PaletteAction(
        Icons.brightness_6_outlined,
        'Toggle theme',
        () {
          final current = ref.read(settingsProvider).theme;
          final next = switch (current) {
            ThemePref.dark => ThemePref.light,
            ThemePref.light => ThemePref.system,
            ThemePref.system => ThemePref.dark,
          };
          settings.setTheme(next);
          _close();
        },
        hint: 'theme',
      ),
      _PaletteAction(
        Icons.qr_code_2,
        'Pair a new host',
        () => _go('/pair'),
        hint: 'pair',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actions().where((a) => _matches(a.label)).toList();
    final sessions = ref
        .watch(sessionsListProvider)
        .where((s) => _matches(_sessionLabel(s)) || _matches(s.cwd))
        .take(8)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          child: PiSearchField(
            value: _query,
            onChange: (q) => setState(() => _query = q),
            placeholder: 'Search actions and sessions…',
            semanticLabel: 'Command palette search',
            autoFocus: true,
            onSubmit: () {
              if (actions.isNotEmpty) {
                actions.first.run();
              } else if (sessions.isNotEmpty) {
                _openSession(sessions.first);
              }
            },
          ),
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
            shrinkWrap: true,
            children: [
              if (actions.isNotEmpty) ...[
                const _SectionHeader('ACTIONS'),
                for (final action in actions)
                  _PaletteRow(
                    icon: action.icon,
                    label: action.label,
                    hint: action.hint,
                    onTap: action.run,
                  ),
              ],
              if (sessions.isNotEmpty) ...[
                const _SectionHeader('SESSIONS'),
                for (final session in sessions)
                  _PaletteRow(
                    icon: Icons.chat_bubble_outline,
                    label: _sessionLabel(session),
                    hint: _shortPath(session.cwd),
                    onTap: () => _openSession(session),
                  ),
              ],
              if (actions.isEmpty && sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No matches for "$_query"',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: PiColors.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _openSession(RpcSessionInfo session) {
    _close();
    Navigator.of(context).pushNamed('/chat', arguments: {
      'hostId': widget.hostId,
      'sessionPath': session.path,
    });
  }

  static String _sessionLabel(RpcSessionInfo s) => s.name?.isNotEmpty == true
      ? s.name!
      : (s.firstMessage?.isNotEmpty == true
          ? s.firstMessage!
          : s.path.split('/').last);

  static String _shortPath(String cwd) {
    if (cwd.isEmpty) return '';
    final parts = cwd.split('/').where((p) => p.isNotEmpty).toList();
    return parts.length <= 2
        ? cwd
        : '…/${parts.sublist(parts.length - 2).join('/')}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontFamily: PiFonts.mono,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: PiColors.textFaint,
          ),
        ),
      );
}

class _PaletteRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback onTap;

  const _PaletteRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PiRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: PiColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: PiColors.text),
              ),
            ),
            if (hint != null && hint!.isNotEmpty)
              Text(
                hint!,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: PiFonts.mono,
                  color: PiColors.textFaint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
