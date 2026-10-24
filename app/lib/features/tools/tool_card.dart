// lib/features/tools/tool_card.dart
library;
/// Tool card renderers — map toolName → card (doc 06 §4.3).
/// Bash, Read, Edit (with diff), Write, Grep/Find/Ls, generic.

import 'package:flutter/material.dart';
import '../../design/components/chip.dart';
import '../../design/theme.dart';

enum ToolCardType { bash, read, edit, write, search, task, unknown }

class ToolCard extends StatefulWidget {
  final String toolName;
  final Map<String, dynamic> args; // parsed from tool_execution_start args
  final Object? result; // from tool_execution_end result
  final bool isError;
  final VoidCallback? onTap; // tap → detail sheet

  const ToolCard({
    super.key,
    required this.toolName,
    required this.args,
    this.result,
    this.isError = false,
    this.onTap,
  });

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> {
  bool _expanded = false;

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

  @override
  Widget build(BuildContext context) {
    final c = PiColors.of(context);

    return InkWell(
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
            _buildHeadline(c),
            if (_expanded) ...[
              const SizedBox(height: 8),
              _buildDetail(c),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeadline(PiPalette c) {
    final summary = _summary;
    return Row(
      children: [
        Icon(_glyph, size: 16, color: widget.isError ? PiColors.error : PiColors.toolIdentity),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.toolName,
            style: const TextStyle(fontSize: 13, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (summary != null) ...[
          const SizedBox(width: 8),
          StatusChip(
            label: summary,
            variant: widget.isError ? ChipVariant.error : ChipVariant.success,
          ),
        ],
        const SizedBox(width: 4),
        Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: c.textFaint),
      ],
    );
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

  IconData get _glyph => switch (_type) {
        ToolCardType.bash => Icons.terminal_rounded,
        ToolCardType.read => Icons.insert_drive_file_rounded,
        ToolCardType.edit => Icons.edit_outlined,
        ToolCardType.write => Icons.note_add_rounded,
        ToolCardType.search => Icons.search_rounded,
        ToolCardType.task => Icons.account_tree_rounded,
        ToolCardType.unknown => Icons.code_rounded,
      };

  Widget _buildDetail(PiPalette c) {
    final mono = TextStyle(fontSize: 12, fontFamily: 'JetBrains Mono', color: PiColors.text);

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
    final labelStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: PiColors.textSecondary);

    switch (_type) {
      case ToolCardType.bash:
        final r = _resultMap;
        final stdout = r?['stdout'] is String ? r!['stdout'] as String : null;
        return [
          Text('Command', style: labelStyle),
          const SizedBox(height: 2),
          Text(widget.args['command'] as String? ?? '', style: mono),
          if (stdout != null && stdout.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Output', style: labelStyle),
            const SizedBox(height: 2),
            Text(
              stdout,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: mono.copyWith(color: PiColors.textSecondary),
            ),
          ],
        ];
      case ToolCardType.edit:
        final diff = _diffText;
        if (widget.isError) {
          return [Text('Tool execution failed', style: TextStyle(color: PiColors.error, fontSize: 12))];
        }
        if (diff == null || diff.isEmpty) {
          return [Text('No changes', style: TextStyle(fontSize: 12, color: PiColors.textMuted))];
        }
        final lines = diff.split('\n');
        return [
          for (final line in lines.take(20)) DiffRow(line: line),
          if (lines.length > 20)
            Text('… ${lines.length - 20} more lines', style: TextStyle(fontSize: 11, color: PiColors.textFaint)),
        ];
      case ToolCardType.read:
      case ToolCardType.write:
        return [Text(widget.args['path'] as String? ?? '', style: mono)];
      case ToolCardType.search:
        final r = _resultMap;
        final matches = r?['matches'];
        return [
          Text('Query', style: labelStyle),
          const SizedBox(height: 2),
          Text(
            (widget.args['pattern'] ?? widget.args['path'] ?? '').toString(),
            style: mono,
          ),
          if (matches is List) ...[
            const SizedBox(height: 4),
            Text('${matches.length} results', style: TextStyle(fontSize: 12, color: PiColors.success)),
          ],
        ];
      case ToolCardType.task:
        return [Text('Task graph — full view in a later milestone', style: TextStyle(fontSize: 12, color: PiColors.textMuted))];
      case ToolCardType.unknown:
        return [
          SelectableText(
            widget.args.toString(),
            style: mono.copyWith(fontSize: 11, color: PiColors.textSecondary),
          ),
          if (widget.result != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              _truncate(widget.result.toString()),
              style: mono.copyWith(fontSize: 11, color: PiColors.textMuted),
            ),
          ],
        ];
    }
  }

  String _truncate(String s) {
    if (s.length <= 400) return s;
    return '${s.substring(0, 400)}…';
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