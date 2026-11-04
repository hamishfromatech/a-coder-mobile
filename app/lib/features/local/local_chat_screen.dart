// On-device chat screen. LFM3 runs locally through llama.cpp; no bridge or
// cloud connection is used here.

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/button.dart';
import '../../design/primitives.dart';
import '../../design/theme.dart';
import 'local_chat_controller.dart';

class LocalChatScreen extends ConsumerStatefulWidget {
  const LocalChatScreen({super.key});

  @override
  ConsumerState<LocalChatScreen> createState() => _LocalChatScreenState();
}

class _LocalChatScreenState extends ConsumerState<LocalChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _importModel() async {
    const type = XTypeGroup(label: 'GGUF model', extensions: ['gguf']);
    final file = await openFile(acceptedTypeGroups: const [type]);
    if (file == null) return;
    await ref.read(localChatControllerProvider.notifier).importModel(file);
  }

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    ref.read(localChatControllerProvider.notifier).send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(localChatControllerProvider.notifier);
    final state = ref.watch(localChatControllerProvider);
    ref.listen(localChatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          next.generating) {
        _scrollToBottom();
      }
      if (next.error != null && next.error != previous?.error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.error!)),
          );
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('On-device'),
            Text(
              'LFM3 · offline',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          if (state.modelLoaded)
            IconButton(
              tooltip: 'New chat',
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: controller.newChat,
            ),
          IconButton(
            tooltip: 'Model',
            icon: const Icon(Icons.memory),
            onPressed: () => _showModelSheet(context, state),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (state.error != null)
                Container(
                  width: double.infinity,
                  color: PiColors.error.withValues(alpha: 0.12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(
                    state.error!,
                    style: TextStyle(fontSize: 11, color: PiColors.error),
                  ),
                ),
              Expanded(
                child: state.loadingModel
                    ? _buildLoading(context)
                    : !state.modelReady
                        ? _buildSetup(context, state)
                        : !state.modelLoaded
                            ? _buildReady(context, state)
                            : _buildChat(context, state),
              ),
            ],
          ),
          if (state.downloading || state.importing)
            _BusyOverlay(
              state: state,
              onCancel: state.downloading ? controller.cancelDownload : null,
            ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading LFM3-1.7B…', style: TextStyle(fontSize: 13)),
          SizedBox(height: 6),
          Text(
            'First load takes a few seconds.',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSetup(BuildContext context, LocalChatState state) {
    final c = PiColors.of(context);
    final spec = ref.read(localChatControllerProvider.notifier).spec;
    final busy = state.importing || state.downloading;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Icon(Icons.memory_rounded, size: 52, color: c.accent),
        const SizedBox(height: 14),
        const Text(
          'LFM3 on this phone',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'A local model for chat and voice. No desktop, no cloud, no '
          'network after setup.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(PiRadius.xl),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      spec.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    spec.quantization,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: PiFonts.mono,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${spec.displaySize} · ${spec.license}',
                style: TextStyle(fontSize: 11, color: c.textMuted),
              ),
              const SizedBox(height: 10),
              Text(
                'Keep at least 2 GB free. 6–8 GB RAM recommended. '
                'The model file is memory-mapped from app storage.',
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
            ],
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 18),
          LinearProgressIndicator(value: state.progress),
          const SizedBox(height: 8),
          Text(
            state.importing
                ? 'Importing model…'
                : 'Downloading model${state.progress != null ? ' ${(state.progress! * 100).round()}%' : '…'}',
            style: TextStyle(fontSize: 11, color: c.textMuted),
          ),
          if (state.downloading)
            TextButton(
              onPressed: () =>
                  ref.read(localChatControllerProvider.notifier).cancelDownload(),
              child: const Text('Cancel download'),
            ),
        ],
        const SizedBox(height: 20),
        PiButton(
          label: 'Import GGUF…',
          icon: Icons.file_open_outlined,
          variant: PiButtonVariant.primary,
          size: PiButtonSize.lg,
          expanded: true,
          onPressed: busy ? null : _importModel,
        ),
        const SizedBox(height: 10),
        PiButton(
          label: 'Download from Hugging Face',
          icon: Icons.download_outlined,
          variant: PiButtonVariant.outline,
          size: PiButtonSize.lg,
          expanded: true,
          onPressed: busy
              ? null
              : () => ref
                  .read(localChatControllerProvider.notifier)
                  .downloadModel(),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: spec.url));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Model URL copied')),
            );
          },
          icon: const Icon(Icons.link, size: 16),
          label: const Text('Copy model URL'),
        ),
        const SizedBox(height: 12),
        Text(
          'For a phone with little or no data, download the GGUF on a '
          'computer and transfer it by USB, SD card or another phone, then '
          'use Import.',
          style: TextStyle(fontSize: 11, color: c.textMuted, height: 1.4),
        ),
        const SizedBox(height: 18),
        Text(
          'LFM3 is released under the LFM Open License v1.0. Commercial use '
          'is subject to its revenue threshold and attribution terms.',
          style: TextStyle(fontSize: 10, color: c.textFaint, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildReady(BuildContext context, LocalChatState state) {
    final c = PiColors.of(context);
    final spec = ref.read(localChatControllerProvider.notifier).spec;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 42, color: c.success),
            const SizedBox(height: 14),
            Text(
              '${spec.name} is ready',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              '${spec.displaySize} on this phone. Loading takes a moment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            const SizedBox(height: 20),
            PiButton(
              label: 'Load model',
              icon: Icons.play_arrow_rounded,
              variant: PiButtonVariant.primary,
              size: PiButtonSize.lg,
              onPressed: state.loadingModel
                  ? null
                  : () =>
                      ref.read(localChatControllerProvider.notifier).loadModel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChat(BuildContext context, LocalChatState state) {
    final c = PiColors.of(context);
    return Column(
      children: [
        Expanded(
          child: state.messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.offline_bolt_outlined,
                            size: 42, color: c.accent),
                        const SizedBox(height: 14),
                        const Text(
                          'Ask anything.',
                          style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Runs on this phone. Nothing is sent anywhere.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                    final message = state.messages[index];
                    return _MessageBubble(message: message);
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _composer,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (!state.generating) _send();
                    },
                    decoration: InputDecoration(
                      hintText: 'Message LFM3…',
                      isDense: true,
                      filled: true,
                      fillColor: c.surfaceRaised,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PiRadius.lg),
                        borderSide: BorderSide(color: c.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PiRadius.lg),
                        borderSide: BorderSide(color: c.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PiRadius.lg),
                        borderSide: BorderSide(color: c.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: state.generating ? 'Stop' : 'Send',
                  onPressed: state.generating
                      ? () => ref
                          .read(localChatControllerProvider.notifier)
                          .stop()
                      : _send,
                  icon: Icon(
                    state.generating ? Icons.stop_rounded : Icons.arrow_upward,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showModelSheet(
    BuildContext context,
    LocalChatState state,
  ) async {
    final controller = ref.read(localChatControllerProvider.notifier);
    final spec = controller.spec;
    final c = PiColors.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  spec.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${spec.quantization} · ${spec.displaySize} · ${spec.license}',
                  style: TextStyle(fontSize: 11, color: c.textMuted),
                ),
                const SizedBox(height: 12),
                if (state.modelLoaded)
                  ListTile(
                    leading: const Icon(Icons.eject_outlined),
                    title: const Text('Unload model'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      controller.unloadModel();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.file_open_outlined),
                  title: const Text('Import another GGUF…'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _importModel();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Download model'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    controller.downloadModel();
                  },
                ),
                if (state.modelReady)
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: c.error),
                    title: Text(
                      'Delete model from this phone',
                      style: TextStyle(color: c.error),
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await controller.deleteModel();
                    },
                  ),
                const SizedBox(height: 6),
                Text(
                  'LFM3 runs entirely on-device through llama.cpp. No Qwen '
                  'TTS or other speech model is involved.',
                  style: TextStyle(fontSize: 10, color: c.textFaint),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({required this.state, this.onCancel});

  final LocalChatState state;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final c = PiColors.of(context);
    final percent = state.progress == null
        ? null
        : (state.progress! * 100).round();
    final label = state.importing
        ? 'Importing model…'
        : percent == null
            ? 'Starting download…'
            : 'Downloading model $percent%';
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 300,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(PiRadius.xl),
              border: Border.all(color: c.borderStrong),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.downloading_rounded, size: 34, color: c.accent),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: state.progress),
                const SizedBox(height: 10),
                Text(
                  state.importing
                      ? 'Copying the GGUF into app storage. Keep this screen open.'
                      : 'About 1.1 GB. Keep this screen open on a good connection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
                if (onCancel != null) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel download'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final LocalChatMessage message;

  @override
  Widget build(BuildContext context) {
    final c = PiColors.of(context);
    final isUser = message.role == LocalChatRole.user;
    final thinking = message.thinking.trim();
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        decoration: BoxDecoration(
          color: isUser ? c.accent : c.surfaceRaised,
          borderRadius: BorderRadius.circular(PiRadius.xl),
          border: Border.all(color: isUser ? c.accent : c.border),
        ),
        child: isUser
            ? SelectableText(
                message.text,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Colors.white,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (thinking.isNotEmpty)
                    _LocalThinkingBlock(thinking: thinking),
                  if (thinking.isNotEmpty && message.text.isNotEmpty)
                    const SizedBox(height: 8),
                  if (message.text.isEmpty)
                    Text(
                      '▋',
                      style: TextStyle(fontSize: 13, color: c.textMuted),
                    )
                  else
                    _LocalMarkdown(data: message.text),
                ],
              ),
      ),
    );
  }
}

class _LocalThinkingBlock extends StatefulWidget {
  const _LocalThinkingBlock({required this.thinking});

  final String thinking;

  @override
  State<_LocalThinkingBlock> createState() => _LocalThinkingBlockState();
}

class _LocalThinkingBlockState extends State<_LocalThinkingBlock> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final c = PiColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(PiRadius.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 15,
                    color: c.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Thinking',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(9, 0, 9, 8),
                child: SelectableText(
                  widget.thinking,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocalMarkdown extends StatelessWidget {
  const _LocalMarkdown({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final c = PiColors.of(context);
    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 13, height: 1.5, color: c.text),
        h1: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
        h2: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
        h3: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
        strong: const TextStyle(fontWeight: FontWeight.w600),
        em: const TextStyle(fontStyle: FontStyle.italic),
        code: TextStyle(
          fontSize: 12,
          fontFamily: PiFonts.mono,
          color: c.accent,
          backgroundColor: c.surface,
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFF0A0A0C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        blockquote: TextStyle(
          fontSize: 13,
          color: c.textSecondary,
        ),
        listBullet: TextStyle(fontSize: 13, color: c.text),
      ),
    );
  }
}
