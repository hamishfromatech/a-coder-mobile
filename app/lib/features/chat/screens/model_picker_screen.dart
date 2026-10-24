// lib/features/chat/screens/model_picker_screen.dart
library;
/// Model picker — search field, grouped by provider (doc 06 §4).
/// Wired in M3: models from get_available_models, selection → set_model.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design/theme.dart';
import '../../../design/components/chip.dart';
import '../../pairing/providers/connection_providers.dart';
import '../providers/chat_providers.dart';

/// Fetch models over RPC (autoDispose refetches on next open).
final availableModelsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final hostId = ref.watch(activeHostIdProvider).value ?? '';
  if (hostId.isEmpty) return [];
  return ref.watch(sessionControllerProvider(hostId).notifier).getAvailableModels();
});

class ModelPickerScreen extends ConsumerStatefulWidget {
  const ModelPickerScreen({super.key});

  @override ConsumerState<ModelPickerScreen> createState() => _ModelPickerScreenState();
}

class _ModelPickerScreenState extends ConsumerState<ModelPickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> models) {
    if (_query.isEmpty) return models;
    return models.where((m) {
      final name = (m['name'] as String? ?? '').toLowerCase();
      final provider = (m['provider'] as String? ?? '').toLowerCase();
      final id = (m['id'] as String? ?? '').toLowerCase();
      return name.contains(_query) || provider.contains(_query) || id.contains(_query);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _grouped(List<Map<String, dynamic>> models) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final m in models) {
      final provider = m['provider'] as String? ?? 'Other';
      groups.putIfAbsent(provider, () => []).add(m);
    }
    return groups;
  }

  @override Widget build(BuildContext context) {
    final modelsAsync = ref.watch(availableModelsProvider);
    final session = ref.watch(chatStateProvider).session;
    final currentModel = session.model;
    final currentProvider = session.modelProvider;
    final hostId = ref.watch(activeHostIdProvider).value ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Select Model')),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (q) => setState(() => _query = q.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search models...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          // Model list grouped by provider
          Expanded(
            child: modelsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load models'),
                    const SizedBox(height: 4),
                    Text('$e', style: const TextStyle(fontSize: 12, color: PiColors.textMuted)),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.invalidate(availableModelsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (models) {
                final grouped = _grouped(_filtered(models));
                if (grouped.isEmpty) {
                  return const Center(child: Text('No models match', style: TextStyle(color: PiColors.textMuted)));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    try {
                      await ref.read(sessionControllerProvider(hostId).notifier).refreshModels();
                    } catch (_) {}
                    ref.invalidate(availableModelsProvider);
                  },
                  child: ListView(
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PiColors.textSecondary)),
                          ),
                          ...entry.value.map((model) => _ModelRow(
                                model: model,
                                isCurrent: (model['id'] as String? ?? '') == currentModel && (model['provider'] as String? ?? '') == currentProvider,
                                onSelected: () => _selectModel(hostId, model),
                              )),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectModel(String hostId, Map<String, dynamic> model) async {
    final id = model['id'] as String?;
    final provider = model['provider'] as String? ?? '';
    if (id == null || id.isEmpty || hostId.isEmpty) return;
    try {
      await ref.read(sessionControllerProvider(hostId).notifier).setModel(provider, id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not switch model — not connected')),
        );
      }
    }
  }
}

class _ModelRow extends StatelessWidget {
  final Map<String, dynamic> model;
  final bool isCurrent;
  final VoidCallback onSelected;

  const _ModelRow({required this.model, required this.isCurrent, required this.onSelected});

  @override Widget build(BuildContext context) {
    final name = model['name'] as String? ?? model['id'] as String? ?? 'Unknown';
    final contextWindow = (model['contextWindow'] as num?)?.toInt();
    final reasoning = model['reasoning'] as bool? ?? false;

    return ListTile(
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          if (contextWindow != null) Text('${contextWindow}K ctx', style: const TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono', color: PiColors.textMuted)),
          if (contextWindow != null && reasoning) const SizedBox(width: 8),
          if (reasoning) const StatusChip(label: 'reasoning', variant: ChipVariant.muted),
        ],
      ),
      trailing: isCurrent
          ? const Icon(Icons.check_rounded, color: PiColors.accent)
          : const Icon(Icons.chevron_right, size: 20, color: PiColors.textFaint),
      onTap: onSelected,
    );
  }
}
