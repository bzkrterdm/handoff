import 'dart:io';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/stack/base/data/local_storage.dart';
import 'package:handoff/stack/core/ioc/service_locator.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Exercises the whole storage path — hive_ce box, the AES-GCM cipher and the
/// key kept in secure storage — with the two plugins faked in memory.
void main() {
  late Directory directory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('handoff_storage');
    PathProviderPlatform.instance = _FakePathProvider(directory.path);
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    locator.initialize(
      external: () {
        locator.registerFactoryParam<_Profile, Map<String, dynamic>, void>(
          (json, _) => _Profile.fromJson(json),
        );
      },
    );
  });

  tearDownAll(() async {
    await LocalStorage.dispose();
    await directory.delete(recursive: true);
  });

  group('LocalStorage', () {
    test('stores and reads a primitive by key', () async {
      final storage = _TokenStorage(locator());
      addTearDown(storage.clear);

      expect(await storage.read('token'), isNull);

      await storage.write('token', 'abc123');

      expect(await storage.read('token'), 'abc123');
    });

    test('serializes an object through the locator', () async {
      final storage = _ProfileStorage(locator());
      addTearDown(storage.clear);

      await storage.update(const _Profile(name: 'Ada', age: 36));
      final stored = await storage.read();

      expect(stored?.name, 'Ada');
      expect(stored?.age, 36);
    });

    test('replaces the unique item instead of appending', () async {
      final storage = _ProfileStorage(locator());
      addTearDown(storage.clear);

      await storage.update(const _Profile(name: 'Ada', age: 36));
      await storage.update(const _Profile(name: 'Grace', age: 45));

      expect((await storage.read())?.name, 'Grace');
      expect(await storage.count(), 1);
    });

    test('clears everything it holds', () async {
      final storage = _TokenStorage(locator());

      await storage.write('token', 'abc123');
      await storage.clear();

      expect(await storage.read('token'), isNull);
    });

    test(
      'does not share a box with another storage of the same type',
      () async {
        // Both hold String values; without its own box name the second would
        // read, and clearing it would wipe, the first one's data.
        final tokens = _TokenStorage(locator());
        final notes = _NoteStorage(locator());
        addTearDown(tokens.clear);

        await tokens.write('key', 'token-value');
        await notes.write('key', 'note-value');

        expect(await tokens.read('key'), 'token-value');
        expect(await notes.read('key'), 'note-value');

        await notes.clear();

        expect(await tokens.read('key'), 'token-value');
      },
    );

    test('keeps the box encrypted on disk', () async {
      final storage = _TokenStorage(locator());
      addTearDown(storage.clear);

      await storage.write('token', 'plaintext-canary');
      await LocalStorage.dispose();

      // Hive writes the box under a lower-cased name; a case-insensitive
      // file system hides that, so look the file up instead of naming it.
      final boxFile = directory.listSync().whereType<File>().singleWhere(
        (file) => file.path.toLowerCase().endsWith('/string.hive'),
      );
      expect(
        String.fromCharCodes(boxFile.readAsBytesSync()),
        isNot(contains('plaintext-canary')),
      );
    });
  });
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _TokenStorage extends LocalStorage<String> {
  _TokenStorage(super.logger);

  Future<String?> read(String key) => getSingle(key);

  Future<void> write(String key, String value) => putSingle(key, value);

  Future<void> clear() => clearAll();
}

class _NoteStorage extends LocalStorage<String> {
  _NoteStorage(super.logger);

  @override
  String get boxName => 'Note';

  Future<String?> read(String key) => getSingle(key);

  Future<void> write(String key, String value) => putSingle(key, value);

  Future<void> clear() => clearAll();
}

class _ProfileStorage extends LocalStorage<_Profile> {
  _ProfileStorage(super.logger);

  Future<_Profile?> read() => getUniqueItem();

  Future<void> update(_Profile profile) => updateUniqueItem(profile);

  Future<int> count() async => (await getAll()).length;

  Future<void> clear() => clearAll();
}

class _Profile {
  const _Profile({required this.name, required this.age});

  _Profile.fromJson(Map<String, dynamic> json)
    : name = json['name'],
      age = json['age'];

  final String? name;
  final int? age;

  Map<String, dynamic> toJson() => {'name': name, 'age': age};
}
