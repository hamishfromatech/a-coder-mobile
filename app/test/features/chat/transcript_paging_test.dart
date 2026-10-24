// Transcript paging state (get_transcript_page) — merge/prepend semantics.
import 'package:flutter_test/flutter_test.dart';

import 'package:acoder_mobile/core/protocol/responses.dart';
import 'package:acoder_mobile/features/chat/providers/chat_providers.dart';

TranscriptEntry _entry(String id, String role, String text) => TranscriptEntry(
      id: id,
      type: 'message',
      timestamp: '2026-01-01T00:00:00Z',
      message: {
        'role': role,
        'content': [
          {'type': 'text', 'text': text},
        ],
      },
    );

void main() {
  test('initial page loads newest entries and records the older cursor', () {
    final notifier = ChatStateNotifier();
    addTearDown(notifier.dispose);

    notifier.loadTranscriptPage(TranscriptPageResponse(
      entries: [_entry('e3', 'user', 'third'), _entry('e4', 'assistant', 'fourth')],
      total: 4,
      start: 2,
      end: 4,
      hasMore: true,
    ));

    final state = notifier.state;
    expect(state.messages.map((m) => m.id), ['e3', 'e4']);
    expect(state.olderCursor, 2);
    expect(state.hasMoreBefore, isTrue);
    expect(state.totalEntries, 4);
    expect(state.isLoadingOlder, isFalse);
  });

  test('paging backwards prepends and dedupes by entry id', () {
    final notifier = ChatStateNotifier();
    addTearDown(notifier.dispose);

    notifier.loadTranscriptPage(TranscriptPageResponse(
      entries: [_entry('e3', 'user', 'third')],
      total: 3,
      start: 2,
      end: 3,
      hasMore: true,
    ));
    notifier.setLoadingOlder(true);
    notifier.loadTranscriptPage(TranscriptPageResponse(
      // e3 overlaps the already-loaded tail — must not duplicate.
      entries: [
        _entry('e1', 'user', 'first'),
        _entry('e2', 'assistant', 'second'),
        _entry('e3', 'user', 'third'),
      ],
      total: 3,
      start: 0,
      end: 3,
      hasMore: false,
    ));

    final state = notifier.state;
    expect(state.messages.map((m) => m.id), ['e1', 'e2', 'e3']);
    expect(state.olderCursor, 0);
    expect(state.hasMoreBefore, isFalse);
    expect(state.isLoadingOlder, isFalse);
  });

  test('a fresh page replaces the transcript (session switch/resync)', () {
    final notifier = ChatStateNotifier();
    addTearDown(notifier.dispose);

    notifier.loadTranscriptPage(TranscriptPageResponse(
      entries: [_entry('a', 'user', 'old session')],
      total: 1,
      start: 0,
      end: 1,
      hasMore: false,
    ));
    notifier.loadTranscriptPage(TranscriptPageResponse(
      entries: [_entry('b', 'user', 'new session')],
      total: 10,
      start: 9,
      end: 10,
      hasMore: true,
    ));

    final state = notifier.state;
    expect(state.messages.map((m) => m.id), ['b']);
    expect(state.olderCursor, 9);
    expect(state.hasMoreBefore, isTrue);
  });

  test('non-message entries are ignored', () {
    final notifier = ChatStateNotifier();
    addTearDown(notifier.dispose);

    notifier.loadTranscriptPage(TranscriptPageResponse(
      entries: [
        const TranscriptEntry(
            id: 'c1', type: 'compaction', timestamp: '2026-01-01T00:00:00Z'),
        _entry('m1', 'user', 'hello'),
      ],
      total: 2,
      start: 0,
      end: 2,
      hasMore: false,
    ));

    expect(notifier.state.messages.map((m) => m.id), ['m1']);
  });

  test('reset clears paging state', () {
    final notifier = ChatStateNotifier();
    addTearDown(notifier.dispose);

    notifier.loadTranscriptPage(TranscriptPageResponse(
      entries: [_entry('e1', 'user', 'one')],
      total: 5,
      start: 4,
      end: 5,
      hasMore: true,
    ));
    notifier.reset();
    expect(notifier.state.messages, isEmpty);
    expect(notifier.state.olderCursor, isNull);
    expect(notifier.state.hasMoreBefore, isFalse);
  });
}
