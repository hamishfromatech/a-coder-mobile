// lib/features/chat/providers/markdown_cache.dart
library;
import 'dart:collection';


/// Bounded LRU cache for parsed markdown blocks.
///
/// Keyed by (messageId, contentLength) so a message_update that appends
/// content produces a new key and never reuses a stale render. Content is
/// re-parsed only when the key changes.
class MarkdownBlockCache {
  MarkdownBlockCache({this.capacity = 200});

  final int capacity;
  final LinkedHashMap<String, Object> _cache = LinkedHashMap<String, Object>();

  String keyFor(String messageId, int contentLength) => '$messageId::$contentLength';

  T? get<T>(String messageId, int contentLength) {
    final key = keyFor(messageId, contentLength);
    final v = _cache.remove(key);
    if (v != null) {
      _cache[key] = v;
      return v as T?;
    }
    return null;
  }

  void put(String messageId, int contentLength, Object blocks) {
    final key = keyFor(messageId, contentLength);
    _cache.remove(key);
    _cache[key] = blocks;
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  void clear() => _cache.clear();

  int get length => _cache.length;
}

final markdownBlockCache = MarkdownBlockCache();
