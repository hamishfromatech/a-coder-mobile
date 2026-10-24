// lib/features/tools/tool_card.dart
library;
import 'dart:async';
/// Tool card renderers — map toolName → card (doc 06 §4.3).
/// Bash, Read, Edit (with diff), Write, Grep/Find/Ls, generic.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../design/components/chip.dart';
import '../../design/theme.dart';

enum ToolCardType { bash, read, edit, write, search, task, unknown }

enum ToolCardStatus { running, success, error }

class ToolCard extends StatefulWidget {
  final String toolName;
  final Map<String, dynamic> args; // parsed from tool_execution_start args
  final Object? result; // from tool_execution_end result
  final bool isError;
  final bool isComplete;
  final Object? partialResult;
  final DateTime? startedAt;
  final VoidCallback? onTap; // tap → detail sheet

  const ToolCard({
    super.key,
    required this.toolName,
    required this.args,
    this.result,
    this.isError = false,
    this.isComplete = false,
    this.partialResult,
    this.startedAt,
    this.onTap,
  });

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> {
  bool _expanded = false;
  late final Stopwatch _stopwatch = Stopwatch()..start();
  Timer? _ticker;

  ToolCardType get _type {
    switch (widget.toolName) {
      case 'bash':
        return ToolCardType.bash;
      case 'read':
        return ToolCardType.read;
      case 'edit':
        return ToolCardType.edit;
      case 'write':
        return ToolCardType.write;
      case 'grep':
      case 'find':
      case 'ls':
      case 'glob':
        return ToolCardType.search;
      default:
        if (widget.toolName.startsWith('task')) return ToolCardType.task;
        return ToolCardType.unknown;
    }
  }

  ToolCardStatus get _status {
    if (widget.isError) return ToolCardStatus.error;
    if (widget.isComplete || widget.result != null) return ToolCardStatus.success;
    return ToolCardStatus.running;
  }

  bool get _isRunning => _status == ToolCardStatus.running;

  @override
  void initState() {
    super.initState();
    if (widget.startedAt != null) {
      _stopwatch.reset();
      // keep a lightweight estimate; full precision not required
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = PiColors.of(context);
    final statusColor = switch (_status) {
      ToolCardStatus.running => PiColors.accent,
      ToolCardStatus.success => PiColors.success,
      ToolCardStatus.error => PiColors.error,
    };
    final statusIcon = switch (_status) {
      ToolCardStatus.running => Icons.pending_rounded,
      ToolCardStatus.success => Icons.check_circle_outline,
      ToolCardStatus.error => Icons.error_outline,
    };
    final statusLabel = switch (_status) {
      ToolCardStatus.running => 'Running',
      ToolCardStatus.success => 'Success',
      ToolCardStatus.error => 'Error',
    };

    return Semantics(
      button: true,
      label: 'Tool ${widget.toolName}, $statusLabel',
      child: InkWell(
        onTap: widget.onTap ?? () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.isError ? PiColors.error.withValues(alpha: 0.10) : c.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.isError ? PiColors.error.withValues(alpha: 0.3) : c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.toolName,
                      style: const TextStyle(fontSize: 13, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_summary != null) ...[
                    StatusChip(
                      label: _summary!,
                      variant: widget.isError ? ChipVariant.error : ChipVariant.success,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (_isRunning)
                    Text(
                      _formatElapsed(_stopwatch.elapsed),
                      style: const TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', color: PiColors.textMuted),
                    ),
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: c.textFaint),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _copy(_argsText),
                      icon: const Icon(Icons.copy_all_rounded, size: 14),
                      label: const Text('Copy args', style: TextStyle(fontSize: 11)),
                    ),
                    TextButton.icon(
                      onPressed: () => _copy(_resultText),
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('Copy result', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: SingleChildScrollView(
                    child: _buildDetail(c),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _argsText => const JsonEncoder.withIndent('  ').convert(widget.args);

  String get _resultText {
    if (widget.result == null) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(widget.result);
    } catch (_) {
      return widget.result.toString();
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  String? get _summary {
    switch (_type) {
      case ToolCardType.edit:
        final diff = _diffText;
        if (diff != null) {
          final adds = RegExp(r'^\+').allMatches(diff).length;
          final removes = RegExp(r'^-').allMatches(diff).length;
          return '+$adds −$removes';
        }
        return null;
      case ToolCardType.bash:
        final r = _resultMap;
        if (r != null) {
          final exitCode = (r['exitCode'] as num?)?.toInt() ?? 0;
          return 'exit $exitCode';
        }
        return null;
      case ToolCardType.read:
      case ToolCardType.write:
        final path = widget.args['path'] as String?;
        if (path != null && path.isNotEmpty) {
          final parts = path.split('/');
          return parts.last;
        }
        return null;
      case ToolCardType.search:
        final r = _resultMap;
        final matches = r?['matches'];
        if (matches is List) return '${matches.length} matches';
        return null;
      case ToolCardType.task:
        return 'task';
      case ToolCardType.unknown:
        return null;
    }
  }

  Map<String, dynamic>? get _resultMap {
    final r = widget.result;
    return r is Map<String, dynamic> ? r : null;
  }

  String? get _diffText {
    final r = _resultMap;
    final details = r?['details'];
    if (details is Map<String, dynamic> && details['diff'] is String) {
      return details['diff'] as String;
    }
    if (r?['diff'] is String) return r!['diff'] as String;
    return null;
  }

  Widget _buildDetail(PiPalette c) {
    const mono = TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono', color: PiColors.text);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0C), // detail pane stays dark (desktop parity)
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: PiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._detailChildren(mono),
        ],
      ),
    );
  }

  List<Widget> _detailChildren(TextStyle mono) {
    const labelStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: PiColors.textSecondary);

    switch (_type) {
      case ToolCardType.bash:
        final r = _resultMap;
        final stdout = r?['stdout'] is String ? r!['stdout'] as String : null;
        final lines = stdout?.split('\n') ?? const <String>[];
        final bounded = lines.length > 40 ? lines.take(40).toList() : lines;
        return [
          const Text('Command', style: labelStyle),
          const SizedBox(height: 2),
          Text(widget.args['command'] as String? ?? '', style: mono),
          if (stdout != null && stdout.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Output', style: labelStyle),
            const SizedBox(height: 2),
            for (final line in bounded) Text(line, style: mono.copyWith(color: PiColors.textSecondary)),
            if (lines.length > 40)
              Text('… ${lines.length - 40} more lines', style: const TextStyle(fontSize: 11, color: PiColors.textFaint)),
          ],
        ];
      case ToolCardType.edit:
        final diff = _diffText;
        if (widget.isError) {
          return [const Text('Tool execution failed', style: TextStyle(color: PiColors.error, fontSize: 12))];
        }
        if (diff == null || diff.isEmpty) {
          return [const Text('No changes', style: TextStyle(fontSize: 12, color: PiColors.textMuted))];
        }
        final lines = diff.split('\n');
        final bounded = lines.length > 40 ? lines.take(40).toList() : lines;
        return [
          for (final line in bounded) DiffRow(line: line),
          if (lines.length > 40)
            Text('… ${lines.length - 40} more lines', style: const TextStyle(fontSize: 11, color: PiColors.textFaint)),
        ];
      case ToolCardType.read:
      case ToolCardType.write:
        return [Text(widget.args['path'] as String? ?? '', style: mono)];
      case ToolCardType.search:
        final r = _resultMap;
        final matches = r?['matches'];
        return [
          const Text('Query', style: labelStyle),
          const SizedBox(height: 2),
          Text(
            (widget.args['pattern'] ?? widget.args['path'] ?? '').toString(),
            style: mono,
          ),
          if (matches is List) ...[
            const SizedBox(height: 4),
            Text('${matches.length} results', style: const TextStyle(fontSize: 12, color: PiColors.success)),
          ],
        ];
      case ToolCardType.task:
        return [const Text('Task graph — full view in a later milestone', style: TextStyle(fontSize: 12, color: PiColors.textMuted))];
      case ToolCardType.unknown:
        return [
          SelectableText(
            _safeJson(widget.args),
            style: mono.copyWith(fontSize: 11, color: PiColors.textSecondary),
          ),
          if (widget.result != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              _truncate(_safeJson(widget.result)),
              style: mono.copyWith(fontSize: 11, color: PiColors.textMuted),
            ),
          ],
          if (widget.partialResult != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              _truncate(_safeJson(widget.partialResult)),
              style: mono.copyWith(fontSize: 11, color: PiColors.textMuted),
            ),
          ],
        ];
    }
  }

  String _safeJson(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  String _truncate(String s) {
    if (s.length <= 1000) return s;
    return '${s.substring(0, 1000)}…';
  }

  String _formatElapsed(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
}

/// One diff line: marker + content, colored (doc 06 §4.3).
class DiffRow extends StatelessWidget {
  final String line;

  const DiffRow({super.key, required this.line});

  @override
  Widget build(BuildContext context) {
    final (markerColor, marker) = _classify(line);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            child: Text(
              marker,
              style: TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono', color: markerColor, height: 1.4),
            ),
          ),
          Expanded(
            child: Text(
              line.length > 1 ? line.substring(1) : line,
              style: TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono', color: markerColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) _classify(String line) {
    if (line.startsWith('+')) return (PiColors.success, '+');
    if (line.startsWith('-')) return (PiColors.error, '−');
    if (line.startsWith('@@')) return (PiColors.textFaint, '@');
    return (PiColors.textMuted, ' ');
  }
}
