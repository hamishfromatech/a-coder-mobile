import 'package:acoder_mobile/core/protocol/responses.dart' show Coworker, HuddleSummary, OfficeErrand, OfficeHuddlePayload, OfficeSnapshot;
import 'package:acoder_mobile/design/theme.dart';
import 'package:acoder_mobile/features/office/providers/office_providers.dart';
import 'package:acoder_mobile/features/office/screens/office_screen.dart';
import 'package:acoder_mobile/features/pairing/providers/connection_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSessionController extends SessionController {
  _FakeSessionController(super.ref, super.hostId);
  @override
  Future<void> loadOffice() async {}
  @override
  Future<void> openHuddle(String huddleId) async {}
  @override
  Future<void> sendToHuddle(String huddleId, String text, {List<Map<String, dynamic>>? images}) async {}
  @override
  Future<void> stopHuddle(String huddleId) async {}
  @override
  Future<void> respondOfficePrompt(String requestId, String? choice) async {}
  @override
  // ignore: must_call_super
  void dispose() {}
}

OfficeSnapshot _snapshot({
  List<Coworker> coworkers = const <Coworker>[],
  Map<String, String> statuses = const <String, String>{},
  List<HuddleSummary> huddles = const <HuddleSummary>[],
  List<OfficeErrand> errands = const <OfficeErrand>[],
  List<Map<String, dynamic>> pendingPrompts = const <Map<String, dynamic>>[],
}) =>
    OfficeSnapshot(
      coworkers: coworkers,
      statuses: statuses,
      huddles: huddles,
      errands: errands,
      pendingPrompts: pendingPrompts,
    );

void main() {
  testWidgets('renders roster from overridden provider', (tester) async {
    final snap = _snapshot(
      coworkers: const <Coworker>[Coworker(id: 'c1', name: 'Alice', handle: 'alice', title: 'Engineer', model: 'gpt-4o')],
      statuses: const <String, String>{'c1': 'running'},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider('h1').overrideWith((ref) => _FakeSessionController(ref, 'h1')),
          officeSnapshotProvider.overrideWith((ref) {
            final n = OfficeSnapshotNotifier();
            n.update(snap);
            return n;
          }),
        ],
        child: MaterialApp(theme: PiTheme.dark, home: const OfficeScreen(hostId: 'h1')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Engineer'), findsOneWidget);
    expect(find.text('gpt-4o'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider('h1').overrideWith((ref) => _FakeSessionController(ref, 'h1')),
          officeSnapshotProvider.overrideWith((ref) => OfficeSnapshotNotifier()),
        ],
        child: MaterialApp(theme: PiTheme.dark, home: const OfficeScreen(hostId: 'h1')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('No coworkers yet — set up Your Office on the desktop'), findsOneWidget);
  });

  testWidgets('huddle list renders', (tester) async {
    final snap = _snapshot(huddles: const <HuddleSummary>[
      HuddleSummary(id: 'hud1', name: 'Planning', preview: 'hello', members: <String>['c1', 'c2'], pinned: true, lastActive: 1700000000000),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider('h1').overrideWith((ref) => _FakeSessionController(ref, 'h1')),
          officeSnapshotProvider.overrideWith((ref) {
            final n = OfficeSnapshotNotifier();
            n.update(snap);
            return n;
          }),
        ],
        child: MaterialApp(theme: PiTheme.dark, home: const OfficeScreen(hostId: 'h1')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Planning'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('huddle view renders messages from overridden provider', (tester) async {
    const payload = OfficeHuddlePayload(
      huddleId: 'hud1',
      data: <String, dynamic>{
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{'coworkerId': 'c1', 'content': 'hi there'},
          <String, dynamic>{'role': 'user', 'text': 'hello'},
          <String, dynamic>{'author': 'assistant', 'content': <Map<String, dynamic>>[<String, dynamic>{'type': 'text', 'text': 'reply'}]},
        ],
      },
      working: <String, bool>{'a': true},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider('h1').overrideWith((ref) => _FakeSessionController(ref, 'h1')),
          officeSnapshotProvider.overrideWith((ref) {
            final n = OfficeSnapshotNotifier();
            n.update(_snapshot(coworkers: const <Coworker>[Coworker(id: 'c1', name: 'Alice', handle: 'alice')]));
            return n;
          }),
          officeHuddleProvider.overrideWith((ref) {
            final n = OfficeHuddleNotifier();
            n.update(payload);
            return n;
          }),
        ],
        child: MaterialApp(theme: PiTheme.dark, home: const OfficeHuddleScreen(hostId: 'h1', huddleId: 'hud1')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('hi there'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('reply'), findsOneWidget);
    expect(find.text('Working…'), findsOneWidget);
  });

  testWidgets('pending prompt sheet opens', (tester) async {
    final snap = _snapshot(pendingPrompts: <Map<String, dynamic>>[
      <String, dynamic>{
        'requestId': 'r1',
        'title': 'Proceed?',
        'options': <dynamic>['yes', <String, dynamic>{'label': 'no'}],
      }
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider('h1').overrideWith((ref) => _FakeSessionController(ref, 'h1')),
          officeSnapshotProvider.overrideWith((ref) {
            final n = OfficeSnapshotNotifier();
            n.update(snap);
            return n;
          }),
        ],
        child: MaterialApp(theme: PiTheme.dark, home: const OfficeScreen(hostId: 'h1')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('1 pending prompt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Proceed?'), findsOneWidget);
    expect(find.text('yes'), findsOneWidget);
    expect(find.text('no'), findsOneWidget);
  });

  testWidgets('200% text smoke', (tester) async {
    final snap = _snapshot(
      coworkers: const <Coworker>[Coworker(id: 'c1', name: 'Alice', handle: 'alice', title: 'Engineer', model: 'gpt-4o', description: 'does things')],
      huddles: const <HuddleSummary>[HuddleSummary(id: 'h', name: 'Planning', preview: 'preview text', members: <String>['c1'])],
      errands: const <OfficeErrand>[OfficeErrand(id: 'e1', coworkerId: 'c1', name: 'Errand', prompt: 'do something long')],
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: ProviderScope(
          overrides: [
            sessionControllerProvider('h1').overrideWith((ref) => _FakeSessionController(ref, 'h1')),
            officeSnapshotProvider.overrideWith((ref) {
              final n = OfficeSnapshotNotifier();
              n.update(snap);
              return n;
            }),
          ],
          child: MaterialApp(theme: PiTheme.dark, home: const OfficeScreen(hostId: 'h1')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });
}
