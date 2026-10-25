// Composer attachments — desktop `lib/composer-attachments.ts` parity,
// adapted to a phone client.
//
// The engine runs on the host machine, so a phone cannot hand it a local path.
// What travels:
//   - images  → native vision content (base64), exactly like the desktop
//   - text    → inlined `<file>` blocks, bounded like the desktop
//   - binary  → rejected with a precise reason (the host cannot read the
//               phone's path, so a path reference would be dead weight)
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

export 'package:cross_file/cross_file.dart' show XFile;

const maxComposerAttachments = 8;
const maxImageBytes = 8 * 1024 * 1024;
const maxTextFileBytes = 1024 * 1024;
const maxInlineTextChars = 60000;
const maxTotalInlineTextChars = 120000;

enum AttachmentKind { image, text }

class ComposerAttachment {
  final String name;
  final AttachmentKind kind;
  final int bytes;
  final String? mimeType;
  final Uint8List? data; // image bytes
  final String? text; // inline text

  const ComposerAttachment({
    required this.name,
    required this.kind,
    required this.bytes,
    this.mimeType,
    this.data,
    this.text,
  });
}

class AttachmentException implements Exception {
  final String message;
  const AttachmentException(this.message);
  @override
  String toString() => message;
}

String attachmentName(String path) =>
    path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty).lastOrNull ?? path;

String formatAttachmentBytes(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

bool _isImageMime(String? mime) => const {
      'image/png',
      'image/jpeg',
      'image/gif',
      'image/webp',
      'image/bmp',
    }.contains(mime);

bool _isTextLikeName(String name) {
  final ext = name.split('.').last.toLowerCase();
  return const {
    'txt',
    'md',
    'markdown',
    'json',
    'jsonl',
    'yaml',
    'yml',
    'toml',
    'ini',
    'csv',
    'tsv',
    'log',
    'xml',
    'html',
    'css',
    'scss',
    'js',
    'jsx',
    'ts',
    'tsx',
    'dart',
    'py',
    'rb',
    'go',
    'rs',
    'java',
    'kt',
    'swift',
    'c',
    'h',
    'cpp',
    'hpp',
    'sh',
    'bash',
    'zsh',
    'sql',
    'graphql',
    'patch',
    'diff',
    'env',
    'gitignore',
    'dockerfile',
    'makefile',
  }.contains(ext);
}

/// Load a phone file into an attachment, enforcing the desktop budgets.
Future<ComposerAttachment> attachmentFromXFile(XFile file) async {
  final name = file.name.isNotEmpty ? file.name : attachmentName(file.path);
  final bytes = await file.length();
  final mime = file.mimeType;
  final imageLike = _isImageMime(mime) || (mime?.startsWith('image/') ?? false);

  if (imageLike) {
    if (bytes > maxImageBytes) {
      throw AttachmentException(
          '"$name" is larger than ${formatAttachmentBytes(maxImageBytes)}.');
    }
    return ComposerAttachment(
      name: name,
      kind: AttachmentKind.image,
      bytes: bytes,
      mimeType: mime ?? _mimeFromName(name),
      data: await file.readAsBytes(),
    );
  }

  if (_isTextLikeName(name)) {
    if (bytes > maxTextFileBytes) {
      throw AttachmentException(
          '"$name" is larger than ${formatAttachmentBytes(maxTextFileBytes)}.');
    }
    final text = await file.readAsString();
    if (text.contains('\u0000')) {
      throw AttachmentException('"$name" is not a text file.');
    }
    return ComposerAttachment(
      name: name,
      kind: AttachmentKind.text,
      bytes: bytes,
      mimeType: 'text/plain',
      text: text,
    );
  }

  throw AttachmentException(
      '"$name" can\'t be sent from the phone — only images and text files '
      'travel to the host.');
}

String _mimeFromName(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    _ => 'image/jpeg',
  };
}

String _escapeAttribute(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Build the prompt text and native image content (desktop
/// `buildAttachmentPrompt`). Inline text is bounded per file and in total.
({String text, List<Map<String, dynamic>> images}) buildAttachmentPrompt(
  String text,
  List<ComposerAttachment> attachments,
) {
  final images = <Map<String, dynamic>>[];
  final blocks = <String>[];
  var remainingInline = maxTotalInlineTextChars;

  for (final attachment in attachments) {
    if (attachment.kind == AttachmentKind.image && attachment.data != null) {
      images.add({
        'type': 'image',
        'data': base64Encode(attachment.data!),
        'mimeType': attachment.mimeType ?? 'image/jpeg',
      });
      continue;
    }
    final inline = attachment.text ?? '';
    if (inline.isEmpty) {
      blocks.add(
        '<file name="${_escapeAttribute(attachment.name)}" '
        'type="${_escapeAttribute(attachment.mimeType ?? 'text/plain')}" '
        'bytes="${attachment.bytes}">[Attached from the phone composer; '
        'contents were empty.]</file>',
      );
      continue;
    }
    final budget = remainingInline < maxInlineTextChars
        ? remainingInline
        : maxInlineTextChars;
    final clipped =
        inline.length > budget ? inline.substring(0, budget) : inline;
    remainingInline -= clipped.length;
    final truncated = clipped.length < inline.length
        ? '\n… truncated (${formatAttachmentBytes(attachment.bytes)} total)'
        : '';
    blocks.add(
      '<file name="${_escapeAttribute(attachment.name)}" '
      'type="${_escapeAttribute(attachment.mimeType ?? 'text/plain')}" '
      'bytes="${attachment.bytes}">\n$clipped$truncated\n</file>',
    );
    if (remainingInline <= 0) break;
  }

  final joined = blocks.isEmpty ? text : '$text\n\n${blocks.join('\n')}';
  return (text: joined, images: images);
}
