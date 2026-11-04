// On-device chat screen. LFM3 runs locally through llama.cpp; no bridge or
// cloud connection is used here.

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../design/components/button.dart';
import '../../design/primitives.dart';
import '../../design/theme.dart';
import 'local_chat_controller.dart';
import 'local_model_store.dart';

class LocalChatScreen extends ConsumerStatefulWidget {
  final LocalModelSpec spec;

  const LocalChatScreen({super.key, required this.spec});

  @override
  ConsumerState<LocalChatScreen> createState() => _LocalChatScreenState();
}

class _LocalChatScreenState extends ConsumerState<LocalChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  AudioRecorder? _recorder;
  bool _recording = false;
  String? _recordPath;
  Timer? _recordTimer;
  int _recordSeconds = 0;

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    _recordTimer?.cancel();
    _recorder?.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording();
      return;
    }
    final recorder = AudioRecorder();
    final allowed = await recorder.hasPermission();
    if (!allowed) {
      await recorder.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/acoder-voice-${DateTime.now().millisecondsSinceEpoch}.wav';
    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    if (!mounted) {
      await recorder.dispose();
      return;
    }
    setState(() {
      _recorder = recorder;
      _recording = true;
      _recordPath = path;
      _recordSeconds = 0;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _discardRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    final recorder = _recorder;
    _recorder = null;
    final path = _recordPath;
    _recordPath = null;
    try {
      await recorder?.stop();
    } catch (_) {}
    await recorder?.dispose();
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordSeconds = 0;
    });
  }

  String get _recordLabel {
    final minutes = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (picked == null) return;
    await ref
        .read(localChatControllerProvider(widget.spec.id).notifier)
        .sendImage(picked.path);
    _scrollToBottom(force: true);
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    final recorder = _recorder;
    _recorder = null;
    String? path;
    try {
      path = await recorder?.stop();
    } catch (_) {
      path = null;
    }
    await recorder?.dispose();
    if (!mounted) return;
    setState(() => _recording = false);
    final file = path ?? _recordPath;
    _recordPath = null;
    if (file != null) {
      await ref
          .read(localChatControllerProvider(widget.spec.id).notifier)
          .sendAudio(file);
      _scrollToBottom(force: true);
    }
  }

  Future<void> _importModel() async {
    const type = XTypeGroup(label: 'GGUF model', extensions: ['gguf']);
    final file = await openFile(acceptedTypeGroups: const [type]);
    if (file == null) return;
    XFile? projector;
    if (widget.spec.hasProjector) {
      projector = await openFile(acceptedTypeGroups: const [type]);
      if (projector == null) return;
    }
    await ref
        .read(localChatControllerProvider(widget.spec.id).notifier)
        .importModel(file, projector: projector);
  }

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    ref.read(localChatControllerProvider(widget.spec.id).notifier).send(text);
    _scrollToBottom(force: true);
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (!force &&
          _scroll.position.pixels < _scroll.position.maxScrollExtent - 140) {
        return;
      }
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        ref.read(localChatControllerProvider(widget.spec.id).notifier);
    final state = ref.watch(localChatControllerProvider(widget.spec.id));
    ref.listen(localChatControllerProvider(widget.spec.id), (previous, next) {
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

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        unawaited(
          ref
              .read(localChatControllerProvider(widget.spec.id).notifier)
              .unloadModel(),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('On-device'),
              Text(
                '${widget.spec.name} · offline',
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
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
            if (widget.spec.supportsAudio && !state.speaking)
              IconButton(
                tooltip:
                    state.autoSpeak ? 'Mute spoken replies' : 'Speak replies',
                icon: Icon(state.autoSpeak
                    ? Icons.volume_up_outlined
                    : Icons.volume_off_outlined),
                onPressed: () => ref
                    .read(localChatControllerProvider(widget.spec.id).notifier)
                    .toggleAutoSpeak(),
              ),
            if (state.speaking)
              IconButton(
                tooltip: 'Stop speaking',
                icon: const Icon(Icons.stop_circle_outlined),
                onPressed: () => ref
                    .read(localChatControllerProvider(widget.spec.id).notifier)
                    .stop(),
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
    final spec =
        ref.read(localChatControllerProvider(widget.spec.id).notifier).spec;
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
                spec.hasProjector
                    ? '${spec.displaySize} + ${spec.displayProjectorSize} mmproj · ${spec.license}'
                    : '${spec.displaySize} · ${spec.license}',
                style: TextStyle(fontSize: 11, color: c.textMuted),
              ),
              if (spec.hasProjector) ...[
                const SizedBox(height: 6),
                Text(
                  'Voice mode: speak a question, get a spoken LFM3 answer.',
                  style: TextStyle(fontSize: 11, color: c.accent),
                ),
              ],
              if (spec.supportsVision) ...[
                const SizedBox(height: 4),
                Text(
                  'Attach a photo with the image button. Video input is not '
                  'wired into this Flutter runtime yet.',
                  style: TextStyle(fontSize: 11, color: c.textMuted),
                ),
              ],
              if (spec.hasProjector) ...[
                const SizedBox(height: 4),
                Text(
                  'Import opens two pickers: the main GGUF first, then the mmproj.',
                  style: TextStyle(fontSize: 11, color: c.textMuted),
                ),
              ],
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
              onPressed: () => ref
                  .read(localChatControllerProvider(widget.spec.id).notifier)
                  .cancelDownload(),
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
                  .read(localChatControllerProvider(widget.spec.id).notifier)
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
    final spec =
        ref.read(localChatControllerProvider(widget.spec.id).notifier).spec;
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
                  : () => ref
                      .read(
                          localChatControllerProvider(widget.spec.id).notifier)
                      .loadModel(),
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
                          style:
                              TextStyle(fontSize: 12, color: c.textSecondary),
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
                    return _MessageBubble(
                      message: message,
                      streaming: state.generating &&
                          index == state.messages.length - 1,
                    );
                  },
                ),
        ),
        if (_recording)
          Container(
            width: double.infinity,
            color: PiColors.error.withValues(alpha: 0.12),
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            child: Row(
              children: [
                Icon(Icons.fiber_manual_record,
                    size: 10, color: PiColors.error),
                const SizedBox(width: 7),
                Text(
                  'Recording  $_recordLabel',
                  style: TextStyle(
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: PiColors.error,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _discardRecording,
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _stopRecording,
                  child: const Text('Send'),
                ),
              ],
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
                if (widget.spec.supportsVision) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Attach image',
                    onPressed: state.generating ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined),
                  ),
                ],
                if (widget.spec.supportsAudio) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: _recording ? 'Send voice' : 'Record voice',
                    onPressed:
                        state.generating ? null : () => _toggleRecording(),
                    icon: Icon(
                      _recording ? Icons.stop_circle : Icons.mic_none,
                      color: _recording ? PiColors.error : null,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                IconButton.filled(
                  tooltip: state.generating ? 'Stop' : 'Send',
                  onPressed: state.generating || _recording
                      ? (state.generating
                          ? () => ref
                              .read(localChatControllerProvider(widget.spec.id)
                                  .notifier)
                              .stop()
                          : null)
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
    final controller =
        ref.read(localChatControllerProvider(widget.spec.id).notifier);
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
                for (final other in LocalModelCatalog.all.where(
                  (candidate) => candidate.id != widget.spec.id,
                ))
                  ListTile(
                    leading: Icon(
                      other.supportsVision
                          ? Icons.auto_awesome
                          : other.supportsAudio
                              ? Icons.mic_none
                              : Icons.chat_outlined,
                    ),
                    title: Text('Switch to ${other.name}'),
                    subtitle: Text(
                      other.supportsVision
                          ? 'Text + images + voice + speech output'
                          : other.supportsAudio
                              ? 'Speech input and LFM3 speech output'
                              : 'Smaller text-only model',
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await controller.unloadModel();
                      if (!context.mounted) return;
                      final route = other.id == LocalModelCatalog.text.id
                          ? '/local/text'
                          : other.id == LocalModelCatalog.voice.id
                              ? '/local/voice'
                              : '/local/omni';
                      Navigator.of(context).pushNamed(route);
                    },
                  ),
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
    final percent =
        state.progress == null ? null : (state.progress! * 100).round();
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
  const _MessageBubble({required this.message, this.streaming = false});

  final LocalChatMessage message;
  final bool streaming;

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
                  else if (streaming)
                    SelectableText(
                      message.text,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: c.text,
                      ),
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
