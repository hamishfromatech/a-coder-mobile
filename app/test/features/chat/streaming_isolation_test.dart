import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/features/chat/providers/chat_providers.dart';
import 'package:acoder_mobile/features/chat/providers/markdown_cache.dart';

void main() {
  test('message_update for B does not change message A identity', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(chatStateProvider.notifier);

    notifier.applyEvent('message_start', {
      'message': {
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'A final'},
        ],
        'timestamp': 1,
      },
    });
    notifier.applyEvent('message_end', {
      'message': {
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'A final'},
        ],
        'timestamp': 1,
      },
    });

    notifier.applyEvent('message_start', {
      'message': {
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'B start'},
        ],
        'timestamp': 2,
      },
    });

    final before = container.read(chatStateProvider).messages[0];
    notifier.applyEvent('message_update', {
      'message': {
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'B updated streaming'},
        ],
        'timestamp': 2,
      },
    });
    final after = container.read(chatStateProvider).messages[0];
    expect(identical(before, after), isTrue);
  });

  test('markdown cache does not re-parse unchanged messages', () {
    final cache = MarkdownBlockCache();
    final before = cache.parseCount;
    cache.put('m1', 5, 'hello');
    expect(cache.parseCount, equals(before + 1));
    // unchanged read is a cache hit — no new parse
    expect(cache.get<String>('m1', 5), equals('hello'));
    expect(cache.parseCount, equals(before + 1));
  });
}
