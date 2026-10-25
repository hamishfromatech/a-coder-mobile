// Composer attachment parity: desktop budgets and <file> prompt blocks.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/features/chat/providers/attachments.dart';

void main() {
  test('text attachments become bounded <file> blocks', () {
    final payload = buildAttachmentPrompt('Summarise this', [
      const ComposerAttachment(
        name: 'notes.md',
        kind: AttachmentKind.text,
        bytes: 11,
        mimeType: 'text/plain',
        text: '# Title\nhi',
      ),
    ]);
    expect(payload.text, contains('Summarise this'));
    expect(payload.text, contains('<file name="notes.md"'));
    expect(payload.text, contains('# Title\nhi'));
    expect(payload.images, isEmpty);
  });

  test('images ride as native vision content', () {
    final payload = buildAttachmentPrompt('What is this?', [
      ComposerAttachment(
        name: 'shot.png',
        kind: AttachmentKind.image,
        bytes: 3,
        mimeType: 'image/png',
        data: Uint8List.fromList(const [1, 2, 3]),
      ),
    ]);
    expect(payload.images.single['mimeType'], 'image/png');
    expect(payload.images.single['data'], 'AQID');
    expect(payload.text, 'What is this?');
  });

  test('inline text is clipped at the desktop per-file budget', () {
    final huge = 'x' * (maxInlineTextChars + 500);
    final payload = buildAttachmentPrompt('', [
      ComposerAttachment(
        name: 'big.txt',
        kind: AttachmentKind.text,
        bytes: huge.length,
        text: huge,
      ),
    ]);
    expect(payload.text, contains('… truncated'));
    expect(payload.text.length, lessThan(huge.length));
  });

  test('file names and types are escaped', () {
    final payload = buildAttachmentPrompt('', [
      const ComposerAttachment(
        name: 'a<b>&".txt',
        kind: AttachmentKind.text,
        bytes: 1,
        text: 'x',
      ),
    ]);
    expect(payload.text, contains('a&lt;b&gt;&amp;&quot;.txt'));
  });

  test('byte formatting matches the desktop scale', () {
    expect(formatAttachmentBytes(900), '900 B');
    expect(formatAttachmentBytes(2048), '2.0 KB');
    expect(formatAttachmentBytes(3 * 1024 * 1024), '3.0 MB');
  });
}
