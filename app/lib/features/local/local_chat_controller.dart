// On-device LFM3 chat engine and controller.
//
// The engine lives for the app lifetime (not in build()), so opening and
// closing the screen does not reload a 1 GB model. No desktop bridge and no
// cloud are involved.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llamadart/llamadart.dart';

import 'local_model_store.dart';

enum LocalChatRole { user, assistant }

class LocalChatMessage {
  final LocalChatRole role;
  final String text;
  final String thinking;

  const LocalChatMessage({
    required this.role,
    required this.text,
    this.thinking = '',
  });

  LocalChatMessage copyWith({String? text, String? thinking}) =>
      LocalChatMessage(
        role: role,
        text: text ?? this.text,
        thinking: thinking ?? this.thinking,
      );
}

const _unset = Object();

class LocalChatState {
  final List<LocalChatMessage> messages;
  final bool modelReady;
  final bool modelLoaded;
  final bool loadingModel;
  final bool importing;
  final bool downloading;
  final bool generating;
  final bool speaking;
  final double? progress;
  final String? error;

  const LocalChatState({
    this.messages = const [],
    this.modelReady = false,
    this.modelLoaded = false,
    this.loadingModel = false,
    this.importing = false,
    this.downloading = false,
    this.generating = false,
    this.speaking = false,
    this.progress,
    this.error,
  });

  LocalChatState copyWith({
    List<LocalChatMessage>? messages,
    bool? modelReady,
    bool? modelLoaded,
    bool? loadingModel,
    bool? importing,
    bool? downloading,
    bool? generating,
    bool? speaking,
    Object? progress = _unset,
    Object? error = _unset,
  }) {
    return LocalChatState(
      messages: messages ?? this.messages,
      modelReady: modelReady ?? this.modelReady,
      modelLoaded: modelLoaded ?? this.modelLoaded,
      loadingModel: loadingModel ?? this.loadingModel,
      importing: importing ?? this.importing,
      downloading: downloading ?? this.downloading,
      generating: generating ?? this.generating,
      speaking: speaking ?? this.speaking,
      progress: identical(progress, _unset)
          ? this.progress
          : (progress as num?)?.toDouble(),
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

final localModelStoreProvider = Provider<LocalModelStore>((ref) {
  return LocalModelStore();
});

final localChatControllerProvider = StateNotifierProvider.family<
    LocalChatController, LocalChatState, String>((ref, specId) {
  final spec = LocalModelCatalog.byId(specId) ?? LocalModelCatalog.text;
  final controller = LocalChatController(
    ref.watch(localModelStoreProvider),
    spec,
  );
  unawaited(controller.init());
  return controller;
});

class LocalChatController extends StateNotifier<LocalChatState> {
  LocalChatController(this._store, this._spec)
      : super(const LocalChatState());

  final LocalModelStore _store;
  final LocalModelSpec _spec;

  LlamaEngine? _engine;
  ChatSession? _session;
  StreamSubscription<LlamaCompletionChunk>? _subscription;
  TextToSpeechEngine? _ttsEngine;
  AudioPlayer? _audioPlayer;
  StreamSubscription<void>? _playerComplete;
  bool _cancelDownload = false;
  LocalModelSpec get spec => _spec;

  static const _systemPrompt = '''
You are A-Coder's on-device assistant. You run entirely on the user's phone.
Be concise, practical and honest. If you are unsure, say so.''';

  Future<void> init() async {
    final path = await _store.existingPath(_spec);
    final projector = _spec.hasProjector
        ? await _store.existingPath(_spec, projector: true)
        : null;
    if (!mounted) return;
    state = state.copyWith(
      modelReady: path != null && (!_spec.hasProjector || projector != null),
    );
  }

  Future<void> importModel(XFile source, {XFile? projector}) async {
    if (state.importing || state.downloading) return;
    if (_spec.hasProjector && projector == null) {
      state = state.copyWith(
        error: 'This voice model also needs its mmproj file.',
      );
      return;
    }
    state = state.copyWith(
      importing: true,
      error: null,
      progress: 0.0,
    );
    try {
      await _store.importModel(
        _spec,
        source,
        onProgress: (value) {
          if (!mounted) return;
          state = state.copyWith(progress: value);
        },
      );
      if (_spec.hasProjector) {
        if (!mounted) return;
        state = state.copyWith(progress: 0.0);
        await _store.importModel(
          _spec,
          projector!,
          projector: true,
          onProgress: (value) {
            if (!mounted) return;
            state = state.copyWith(progress: value);
          },
        );
      }
      if (!mounted) return;
      state = state.copyWith(
        importing: false,
        modelReady: true,
        progress: 1.0,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        importing: false,
        progress: null,
        error: 'Import failed: $e',
      );
    }
  }

  Future<void> downloadModel() async {
    if (state.importing || state.downloading) return;
    _cancelDownload = false;
    debugPrint('[local] download start ${_spec.url}');
    state = state.copyWith(
      downloading: true,
      error: null,
      progress: null,
    );
    try {
      await _store.downloadModel(
        _spec,
        onProgress: (value) {
          if (!mounted) return;
          state = state.copyWith(progress: value);
        },
        isCancelled: () => _cancelDownload,
      );
      if (_spec.hasProjector) {
        if (!mounted) return;
        state = state.copyWith(progress: 0.0);
        await _store.downloadModel(
          _spec,
          projector: true,
          onProgress: (value) {
            if (!mounted) return;
            state = state.copyWith(progress: value);
          },
          isCancelled: () => _cancelDownload,
        );
      }
      if (!mounted) return;
      debugPrint('[local] download complete');
      state = state.copyWith(
        downloading: false,
        modelReady: true,
        progress: 1.0,
      );
    } on LocalModelDownloadCancelled {
      debugPrint('[local] download cancelled');
      if (!mounted) return;
      state = state.copyWith(
        downloading: false,
        progress: null,
        error: null,
      );
    } catch (e, st) {
      debugPrint('[local] download failed: $e\n$st');
      if (!mounted) return;
      state = state.copyWith(
        downloading: false,
        progress: null,
        error: 'Download failed: $e',
      );
    }
  }

  void cancelDownload() {
    debugPrint('[local] download cancel requested');
    _cancelDownload = true;
  }

  Future<void> loadModel() async {
    if (state.loadingModel || state.modelLoaded) return;
    final path = await _store.existingPath(_spec);
    if (path == null) {
      if (!mounted) return;
      state = state.copyWith(
        modelReady: false,
        error: 'Model file is missing. Import or download it again.',
      );
      return;
    }
    String? projectorPath;
    if (_spec.hasProjector) {
      projectorPath = await _store.existingPath(_spec, projector: true);
      if (projectorPath == null) {
        if (!mounted) return;
        state = state.copyWith(
          loadingModel: false,
          modelReady: false,
          error: 'The mmproj file is missing. Import or download it again.',
        );
        return;
      }
    }
    state = state.copyWith(loadingModel: true, error: null);
    try {
      final engine = await LlamaEngine.load(
        LlamaModel(
          ModelSource.path(path),
          projector: projectorPath == null
              ? null
              : ModelSource.path(projectorPath),
        ),
      );
      final session = ChatSession(
        engine,
        systemPrompt: _systemPrompt,
        maxContextTokens: 4096,
      );
      if (!mounted) {
        await engine.dispose();
        return;
      }
      _engine = engine;
      _session = session;
      state = state.copyWith(
        loadingModel: false,
        modelLoaded: true,
        modelReady: true,
        error: null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        loadingModel: false,
        error: 'Could not load the model: $e',
      );
    }
  }

  Future<void> unloadModel() async {
    await _stopSpeech();
    _subscription?.cancel();
    _subscription = null;
    final engine = _engine;
    _engine = null;
    _session = null;
    await engine?.dispose();
    if (!mounted) return;
    state = state.copyWith(
      modelLoaded: false,
      generating: false,
      messages: const [],
    );
  }

  Future<void> deleteModel() async {
    await unloadModel();
    await _store.delete(_spec);
    if (!mounted) return;
    state = state.copyWith(
      modelReady: false,
      modelLoaded: false,
      progress: null,
      messages: const [],
    );
  }

  Future<void> send(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || state.generating) return;
    await _generate([LlamaTextContent(prompt)], userText: prompt);
  }

  /// Sends a recorded WAV/encoded audio turn to LFM3-Audio. The model answers
  /// with text; speech output is handled by the LFM3 TTS path.
  Future<void> sendAudio(String path) async {
    if (path.isEmpty || state.generating) return;
    await _generate(
      [
        LlamaAudioContent(path: path),
        const LlamaTextContent('Answer the spoken request in text.'),
      ],
      userText: '🎤 Voice message',
    );
  }

  /// Sends an image turn to LFM3-Omni. Audio and text use the same engine.
  Future<void> sendImage(String path) async {
    if (path.isEmpty || state.generating) return;
    await _generate(
      [
        LlamaImageContent(path: path),
        const LlamaTextContent('Answer the request about this image.'),
      ],
      userText: '🖼 Image',
    );
  }

  Future<void> _generate(
    List<LlamaContentPart> parts, {
    required String userText,
  }) async {
    await _stopSpeech();
    if (!state.modelLoaded) {
      await loadModel();
      if (!state.modelLoaded) return;
    }
    final session = _session;
    if (session == null) return;

    state = state.copyWith(
      generating: true,
      error: null,
      messages: [
        ...state.messages,
        LocalChatMessage(role: LocalChatRole.user, text: userText),
        const LocalChatMessage(role: LocalChatRole.assistant, text: ''),
      ],
    );

    final buffer = StringBuffer();
    final thinking = StringBuffer();
    try {
      final stream = session.create(
        parts,
        params: const GenerationParams(
          maxTokens: 1024,
          temp: 0.1,
          topK: 50,
          penalty: 1.1,
        ),
        enableThinking: true,
      );
      _subscription = stream.listen(
        (chunk) {
          if (!mounted) return;
          buffer.write(chunk.text);
          thinking.write(chunk.thinking);
          _replaceLastAssistant(
            buffer.toString(),
            thinking: thinking.toString(),
          );
        },
        onError: (Object e) {
          if (!mounted) return;
          state = state.copyWith(
            generating: false,
            error: 'Generation failed: $e',
          );
          _subscription = null;
        },
        onDone: () {
          if (!mounted) return;
          final split = _splitThinking(
            answer: buffer.toString(),
            thinking: thinking.toString(),
          );
          _replaceLastAssistant(
            split.answer.isEmpty ? '(no response)' : split.answer,
            thinking: split.thinking,
          );
          state = state.copyWith(generating: false);
          _subscription = null;
          if (_spec.hasProjector && split.answer.isNotEmpty) {
            unawaited(_speak(split.answer));
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        generating: false,
        error: 'Generation failed: $e',
      );
    }
  }

  Future<void> _speak(String text) async {
    final engine = _engine;
    if (engine == null || text.trim().isEmpty) return;
    try {
      _ttsEngine ??= TextToSpeechEngine.attach(
        engine,
        adapter: const Lfm3AudioTtsAdapter(),
      );
      final caps = await _ttsEngine!.capabilities;
      if (!caps.isSupported) {
        debugPrint('[local] TTS unsupported: ${caps.unsupportedReason}');
        return;
      }
      final result = await _ttsEngine!.synthesizeOnce(
        TextToSpeechRequest(text: text, language: 'en'),
      );
      final wav = result.toWavBytes();
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.stop();
      await _playerComplete?.cancel();
      _playerComplete = _audioPlayer!.onPlayerComplete.listen((_) {
        if (mounted) state = state.copyWith(speaking: false);
      });
      await _audioPlayer!.play(BytesSource(wav, mimeType: 'audio/wav'));
      if (mounted) state = state.copyWith(speaking: true);
    } catch (e, st) {
      debugPrint('[local] TTS failed: $e\n$st');
      if (mounted) state = state.copyWith(speaking: false);
    }
  }

  Future<void> _stopSpeech() async {
    await _audioPlayer?.stop();
    await _playerComplete?.cancel();
    _playerComplete = null;
    try {
      await _ttsEngine?.dispose();
    } catch (_) {}
    _ttsEngine = null;
    if (mounted && state.speaking) state = state.copyWith(speaking: false);
  }

  /// Some templates put the reasoning marker inside the text stream rather
  /// than the thinking channel. Normalize both shapes.
  ({String thinking, String answer}) _splitThinking({
    required String answer,
    required String thinking,
  }) {
    var cleanAnswer = answer.trim();
    var cleanThinking = thinking.trim();
    if (cleanThinking.isEmpty) {
      final end = cleanAnswer.lastIndexOf('</think>');
      if (end >= 0) {
        cleanThinking = cleanAnswer.substring(0, end).trim();
        cleanAnswer = cleanAnswer.substring(end + 9).trim();
      }
    }
    return (thinking: cleanThinking, answer: cleanAnswer);
  }

  void _replaceLastAssistant(String text, {String thinking = ''}) {
    final messages = List<LocalChatMessage>.from(state.messages);
    if (messages.isEmpty) return;
    final last = messages.length - 1;
    if (messages[last].role != LocalChatRole.assistant) return;
    messages[last] = messages[last].copyWith(
      text: text,
      thinking: thinking,
    );
    state = state.copyWith(messages: messages);
  }

  void stop() {
    _engine?.cancelGeneration();
    unawaited(_stopSpeech());
  }

  Future<void> newChat() async {
    await _stopSpeech();
    if (state.generating) {
      _engine?.cancelGeneration();
      await _subscription?.cancel();
      _subscription = null;
    }
    _session?.reset();
    if (!mounted) return;
    state = state.copyWith(
      messages: const [],
      generating: false,
      error: null,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _playerComplete?.cancel();
    _audioPlayer?.dispose();
    _ttsEngine?.dispose();
    final engine = _engine;
    _engine = null;
    _session = null;
    if (engine != null) {
      unawaited(engine.dispose());
    }
    super.dispose();
  }
}
