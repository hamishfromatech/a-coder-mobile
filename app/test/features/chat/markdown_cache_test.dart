import 'package:flutter_test/flutter_test.dart';
import 'package:acoder_mobile/features/chat/providers/markdown_cache.dart';

void main() {
  test('markdown cache keys by message and content length', () {
    final cache = MarkdownBlockCache(capacity: 2);
    cache.put('m1', 5, 'hello');
    expect(cache.get<String>('m1', 5), equals('hello'));
    expect(cache.get<String>('m1', 6), isNull);
    cache.put('m2', 4, 'four');
    cache.put('m3', 4, 'abcd');
    expect(cache.get<String>('m1', 5), isNull); // evicted
  });

  test('no stale render after content growth', () {
    final cache = MarkdownBlockCache();
    cache.put('m1', 5, 'hello');
    cache.put('m1', 6, 'hello!');
    expect(cache.get<String>('m1', 5), equals('hello'));
    expect(cache.get<String>('m1', 6), equals('hello!'));
  });
}
