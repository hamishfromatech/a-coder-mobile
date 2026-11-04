// On-device model catalogue and storage.
//
// Model files are deliberately not bundled in the APK. They are imported from
// local storage or downloaded once, then memory-mapped by llama.cpp.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

class LocalModelSpec {
  final String id;
  final String name;
  final String fileName;
  final String quantization;
  final String url;
  final int approxBytes;
  final String license;

  /// Optional audio-generation projector (LFM3-Audio/VL/Omni).
  final String? projectorFileName;
  final String? projectorUrl;
  final int projectorBytes;
  final bool supportsAudio;
  final bool supportsVision;

  const LocalModelSpec({
    required this.id,
    required this.name,
    required this.fileName,
    required this.quantization,
    required this.url,
    required this.approxBytes,
    required this.license,
    this.projectorFileName,
    this.projectorUrl,
    this.projectorBytes = 0,
    this.supportsAudio = false,
    this.supportsVision = false,
  });

  bool get hasProjector => projectorFileName != null;

  String get displaySize {
    final gb = approxBytes / 1000000000;
    return '${gb.toStringAsFixed(2)} GB';
  }

  String get displayProjectorSize {
    final mb = projectorBytes / 1000000;
    return '${mb.toStringAsFixed(0)} MB';
  }
}

class LocalModelCatalog {
  LocalModelCatalog._();

  /// Text chat model. The audio/omni variants use the same storage path and
  /// will be added as separate specs once the voice path lands.
  static const LocalModelSpec text = LocalModelSpec(
    id: 'lfm3-1.7b-q4km',
    name: 'LFM3-1.7B',
    fileName: 'LFM3-1.7B-Q4_K_M.gguf',
    quantization: 'Q4_K_M',
    url:
        'https://huggingface.co/LiquidAI/LFM3-1.7B-GGUF/resolve/main/LFM3-1.7B-Q4_K_M.gguf',
    approxBytes: 1100000000,
    license: 'LFM Open License v1.0',
  );

  /// Voice chat + ASR + TTS model. The mmproj carries the audio encoder,
  /// depthformer and LiquidCodec decoder.
  static const LocalModelSpec voice = LocalModelSpec(
    id: 'lfm3-audio-2b-q4km',
    name: 'LFM3-Audio-2B',
    fileName: 'LFM3-Audio-2B-Q4_K_M.gguf',
    quantization: 'Q4_K_M',
    url:
        'https://huggingface.co/LiquidAI/LFM3-Audio-2B-GGUF/resolve/main/LFM3-Audio-2B-Q4_K_M.gguf',
    approxBytes: 1100000000,
    license: 'LFM Open License v1.0',
    projectorFileName: 'mmproj-LFM3-Audio-2B-Q4_K_M.gguf',
    projectorUrl:
        'https://huggingface.co/LiquidAI/LFM3-Audio-2B-GGUF/resolve/main/mmproj-LFM3-Audio-2B-Q4_K_M.gguf',
    projectorBytes: 172000000,
    supportsAudio: true,
  );

  /// Multimodal model: text, images, video and audio input; text or speech
  /// output. The current Dart binding supports image/audio; video is native-only.
  static const LocalModelSpec omni = LocalModelSpec(
    id: 'lfm3-omni-2b-q4km',
    name: 'LFM3-Omni-2B',
    fileName: 'LFM3-Omni-2B-Q4_K_M.gguf',
    quantization: 'Q4_K_M',
    url:
        'https://huggingface.co/LiquidAI/LFM3-Omni-2B-GGUF/resolve/main/LFM3-Omni-2B-Q4_K_M.gguf',
    approxBytes: 1100000000,
    license: 'LFM Open License v1.0',
    projectorFileName: 'mmproj-LFM3-Omni-2B-Q4_K_M.gguf',
    projectorUrl:
        'https://huggingface.co/LiquidAI/LFM3-Omni-2B-GGUF/resolve/main/mmproj-LFM3-Omni-2B-Q4_K_M.gguf',
    projectorBytes: 290000000,
    supportsAudio: true,
    supportsVision: true,
  );

  static const List<LocalModelSpec> all = [text, voice, omni];

  static LocalModelSpec? byId(String id) {
    for (final spec in all) {
      if (spec.id == id) return spec;
    }
    return null;
  }
}

class LocalModelDownloadCancelled implements Exception {
  const LocalModelDownloadCancelled();
}

/// Owns the app-private model directory. No network or native calls here.
class LocalModelStore {
  Future<Directory> modelsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/models');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> modelFile(LocalModelSpec spec, {bool projector = false}) async {
    final name = projector ? spec.projectorFileName : spec.fileName;
    if (name == null) {
      throw ArgumentError('${spec.name} has no projector file');
    }
    final dir = await modelsDir();
    return File('${dir.path}/$name');
  }

  Future<String?> existingPath(
    LocalModelSpec spec, {
    bool projector = false,
  }) async {
    final file = await modelFile(spec, projector: projector);
    if (!await file.exists()) return null;
    if (await file.length() <= 0) return null;
    return file.path;
  }

  Future<void> delete(LocalModelSpec spec) async {
    final files = <File>[await modelFile(spec)];
    if (spec.hasProjector) {
      files.add(await modelFile(spec, projector: true));
    }
    for (final file in files) {
      if (await file.exists()) await file.delete();
      final part = File('${file.path}.part');
      if (await part.exists()) await part.delete();
    }
  }

  /// Copies a user-selected GGUF into app-private storage. This is the
  /// offline path: the model can be moved by USB, SD card or another phone.
  Future<String> importModel(
    LocalModelSpec spec,
    XFile source, {
    bool projector = false,
    void Function(double? progress)? onProgress,
  }) async {
    final destination = await modelFile(spec, projector: projector);
    final temp = File('${destination.path}.part');
    if (await temp.exists()) await temp.delete();

    final total = await source.length();
    var received = 0;
    var lastProgress = -1.0;
    final sink = temp.openWrite();
    try {
      await for (final chunk in source.openRead()) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final progress = received / total;
          if (progress - lastProgress >= 0.005) {
            lastProgress = progress;
            onProgress?.call(progress);
          }
        }
      }
      await sink.flush();
      await sink.close();
      if (await destination.exists()) await destination.delete();
      await temp.rename(destination.path);
      onProgress?.call(1);
      return destination.path;
    } catch (_) {
      await sink.close().catchError((_) {});
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }

  /// Downloads the model into app-private storage. Import is preferred on
  /// poor connections; this exists for users who want to fetch it in-app.
  Future<String> downloadModel(
    LocalModelSpec spec, {
    bool projector = false,
    void Function(double? progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final existing = await existingPath(spec, projector: projector);
    if (existing != null) return existing;

    final destination = await modelFile(spec, projector: projector);
    final sourceUrl = projector ? spec.projectorUrl! : spec.url;
    final temp = File('${destination.path}.part');
    if (await temp.exists()) await temp.delete();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 25);
    try {
      final request = await client.getUrl(Uri.parse(sourceUrl));
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(HttpHeaders.userAgentHeader, 'A-Coder-Mobile/1.0');
      request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
      onProgress?.call(null);
      final response = await request
          .close()
          .timeout(const Duration(seconds: 40));
      debugPrint(
        '[local] download HTTP ${response.statusCode} '
        'len=${response.contentLength} url=${response.redirects.isEmpty ? sourceUrl : response.redirects.last.location}',
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Model download failed: HTTP ${response.statusCode}',
          uri: Uri.parse(sourceUrl),
        );
      }
      final total = response.contentLength;
      var received = 0;
      var lastProgress = -1.0;
      final sink = temp.openWrite();
      try {
        await for (final chunk in response.timeout(const Duration(seconds: 60))) {
          if (isCancelled?.call() ?? false) {
            throw const LocalModelDownloadCancelled();
          }
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final progress = received / total;
            if (progress - lastProgress >= 0.005) {
              lastProgress = progress;
              onProgress?.call(progress);
            }
          }
        }
        await sink.flush();
        await sink.close();
      } catch (_) {
        await sink.close().catchError((_) {});
        rethrow;
      }
      if (await destination.exists()) await destination.delete();
      await temp.rename(destination.path);
      onProgress?.call(1);
      return destination.path;
    } catch (e, st) {
      debugPrint('[local] download error: $e\n$st');
      if (await temp.exists()) await temp.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }
}
