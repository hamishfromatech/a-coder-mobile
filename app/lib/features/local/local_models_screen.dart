// On-device model hub. One place to choose text, voice or full Omni mode.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/primitives.dart';
import '../../design/theme.dart';
import 'local_chat_controller.dart';
import 'local_model_store.dart';

class LocalModelsScreen extends ConsumerStatefulWidget {
  const LocalModelsScreen({super.key});

  @override
  ConsumerState<LocalModelsScreen> createState() => _LocalModelsScreenState();
}

class _LocalModelsScreenState extends ConsumerState<LocalModelsScreen> {
  final Map<String, bool> _installed = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final store = ref.read(localModelStoreProvider);
    final next = <String, bool>{};
    for (final spec in LocalModelCatalog.all) {
      final model = await store.existingPath(spec);
      final projector = spec.hasProjector
          ? await store.existingPath(spec, projector: true)
          : null;
      next[spec.id] =
          model != null && (!spec.hasProjector || projector != null);
    }
    if (!mounted) return;
    setState(() {
      _installed
        ..clear()
        ..addAll(next);
      _loading = false;
    });
  }

  String _routeFor(LocalModelSpec spec) {
    if (spec.id == LocalModelCatalog.omni.id) return '/local/omni';
    if (spec.id == LocalModelCatalog.voice.id) return '/local/voice';
    return '/local/text';
  }

  Future<void> _open(LocalModelSpec spec) async {
    await Navigator.of(context).pushNamed(_routeFor(spec));
    if (mounted) await _refresh();
  }

  Future<void> _deleteModel(LocalModelSpec spec) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${spec.name}?'),
        content: Text(
          'This removes ${spec.displaySize}'
          '${spec.hasProjector ? ' + ${spec.displayProjectorSize}' : ''} '
          'from this phone. You can import or download it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: PiColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(localModelStoreProvider).delete(spec);
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = PiColors.of(context);
    final ordered = <LocalModelSpec>[
      LocalModelCatalog.omni,
      LocalModelCatalog.text,
      LocalModelCatalog.voice,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('On-device'),
            Text(
              'Private · offline',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
        children: [
          Icon(Icons.memory_rounded, size: 46, color: c.accent),
          const SizedBox(height: 12),
          const Text(
            'Your models, on your phone',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          Text(
            'No bridge, no cloud. Text, images and voice stay on this device.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 12, color: c.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 22),
          for (final spec in ordered) ...[
            _ModelCard(
              spec: spec,
              recommended: spec.id == LocalModelCatalog.omni.id,
              installed: _installed[spec.id] ?? false,
              loading: _loading,
              onTap: () => _open(spec),
              onDelete: (_installed[spec.id] ?? false)
                  ? () => _deleteModel(spec)
                  : null,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Text(
            'Models are downloaded or imported once, then memory-mapped from '
            'app storage. LFM3 is released under the LFM Open License v1.0.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: c.textFaint, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.spec,
    required this.recommended,
    required this.installed,
    required this.loading,
    required this.onTap,
    this.onDelete,
  });

  final LocalModelSpec spec;
  final bool recommended;
  final bool installed;
  final bool loading;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = PiColors.of(context);
    final capabilities = spec.supportsVision
        ? 'Text · images · voice · speech'
        : spec.supportsAudio
            ? 'Speech in · LFM3 speech out'
            : 'Fast text chat';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PiRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(PiRadius.xl),
            border: Border.all(
              color: recommended ? c.accent.withValues(alpha: 0.55) : c.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(PiRadius.lg),
                ),
                child: Icon(
                  spec.supportsVision
                      ? Icons.auto_awesome
                      : spec.supportsAudio
                          ? Icons.mic_none
                          : Icons.chat_bubble_outline,
                  size: 19,
                  color: c.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            spec.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.accentSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'RECOMMENDED',
                              style: TextStyle(
                                fontSize: 8,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w600,
                                color: c.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      capabilities,
                      style: TextStyle(fontSize: 11, color: c.textSecondary),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      loading
                          ? 'Checking…'
                          : installed
                              ? 'Ready · ${spec.quantization}'
                              : '${spec.displaySize}${spec.hasProjector ? ' + ${spec.displayProjectorSize}' : ''} · set up',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: PiFonts.mono,
                        color: installed ? c.success : c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (installed && onDelete != null)
                IconButton(
                  tooltip: 'Delete model',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon:
                      Icon(Icons.delete_outline, size: 18, color: c.textMuted),
                ),
              Icon(
                installed ? Icons.play_arrow_rounded : Icons.chevron_right,
                color: installed ? c.accent : c.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
