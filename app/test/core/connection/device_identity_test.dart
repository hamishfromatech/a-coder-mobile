// Stable device identity — the value that puts this install in the bridge's
// `serve/clients.json` registry and on the desktop Mobile access card
// (plan/04-bridge-spec.md §5.4).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:acoder_mobile/core/connection/device_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceIdentityStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('generates one id and reuses it across loads', () async {
      final store = DeviceIdentityStore();
      final first = await store.load();
      final second = await DeviceIdentityStore().load();

      expect(first.id, isNotEmpty);
      expect(second.id, first.id, reason: 'id is per install, not per launch');
    });

    test('id satisfies the bridge pattern [A-Za-z0-9._:-]{1,128}', () async {
      final identity = await DeviceIdentityStore().load();
      expect(
        RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(identity.id),
        isTrue,
        reason: 'serve/clients.ts rejects any other id and records nothing',
      );
      expect(identity.id.length, lessThanOrEqualTo(128));
    });

    test('persists the id in preferences so a restart keeps the record',
        () async {
      final identity = await DeviceIdentityStore().load();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(DeviceIdentityStore.idKey), identity.id);
    });

    test('replaces a stored id the bridge would refuse', () async {
      SharedPreferences.setMockInitialValues({
        DeviceIdentityStore.idKey: 'not a valid id!',
      });
      final identity = await DeviceIdentityStore().load();
      expect(identity.id, isNot('not a valid id!'));
      expect(RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(identity.id), isTrue);
    });

    test('default name is a platform label plus a short disambiguator',
        () async {
      final store = DeviceIdentityStore();
      final identity = await store.load();
      final label = switch (identity.platform) {
        'android' => 'Android phone',
        'ios' => 'iPhone',
        'macos' => 'Mac',
        'windows' => 'Windows PC',
        'linux' => 'Linux PC',
        _ => 'Mobile device',
      };
      expect(identity.name, startsWith(label));
      expect(identity.name.length, lessThanOrEqualTo(64));
      expect(identity.platform.length, lessThanOrEqualTo(32));
    });

    test('headers carry the three names the bridge reads', () async {
      const identity = DeviceIdentity(
          id: 'mobile-abc', name: 'Pixel 9', platform: 'android');
      expect(identity.headers, {
        'x-acoder-device-id': 'mobile-abc',
        'x-acoder-device-name': 'Pixel 9',
        'x-acoder-device-platform': 'android',
      });
    });

    test('rename keeps the id and caps the name at 64 characters', () async {
      final store = DeviceIdentityStore();
      final before = await store.load();
      final renamed = await store.rename('a' * 90);

      expect(renamed.id, before.id);
      expect(renamed.name.length, 64);
      expect((await store.load()).name.length, 64);
    });

    test('unavailable preferences still yield a usable identity', () async {
      // A store whose prefs future rejects stands in for a host without the
      // plugin: the connection must still identify itself.
      final store = DeviceIdentityStore(
        sharedPreferences: Future<SharedPreferences>.error(
            StateError('preferences unavailable')),
      );
      final identity = await store.load();
      expect(identity.id, isNotEmpty);
      expect(identity.name, isNotEmpty);
    });
  });
}
