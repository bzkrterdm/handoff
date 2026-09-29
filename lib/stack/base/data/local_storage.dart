import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/ioc/service_locator.dart';
import '../../core/logging/logger.dart';
import 'secure_hive_cipher.dart';

/// Base class for custom local storages.
///
/// Every custom local storage should extend this class as an example as below.
///
/// First, create your model with `fromJson` factory constructor and `toJson`
/// method. Note that, you must either make fields nullable or null-check
/// json values in `fromJson`. Because, if you extend your model at one point,
/// extended fields will be coming as null from the storage at first
/// get operation as they were not there when the object was saved earlier.
///
/// ```dart
/// class Foo {
///   Foo({this.val});
///
///   final String? val;
///
///   Foo.fromJson(Map<String, dynamic> json) : val = json['val'];
///
///   Map<String, dynamic> toJson() => {'val': val};
/// }
/// ```
///
/// Second, register your model in service locator by the help of
/// `fromJson` factory constructor.
///
/// ```dart
/// locator.registerFactoryParam<Foo, Map<String, dynamic>, void>(
///      (json, _) => Foo.fromJson(json),
///    );
/// ```
///
/// Then, create your custom local storage with desired methods.
///
/// ```dart
/// abstract class FooStorage {
///   Future<Foo?> getFoo();
///
///   Future<void> updateFoo(Foo foo);
/// }
///
/// class FooStorageImpl extends LocalStorage<Foo> implements FooStorage {
///   FooStorageImpl(super.logger);
///
///   Future<Foo?> getFoo() {
///     return getUniqueItem();
///   }
///
///   Future<void> updateFoo(Foo foo) async {
///     await updateUniqueItem(foo);
///   }
/// }
/// ```
///
/// At the end, `FooStorage` should also be registered
/// in service locator as below.
///
/// ```dart
/// locator.registerLazySingleton<FooStorage>(() => FooStorageImpl());
/// ```
///
/// `P.S.` If you want to have a local storage for a primitive type,
/// it works out of the box. Just extend this and give the type as generic.
abstract class LocalStorage<T extends Object> {
  LocalStorage(this.logger);

  // Static secure storage instance to be used to fetch Hive encryption key.
  static const _secureStorage = FlutterSecureStorage();

  final Logger logger;

  var _isInitialized = false;

  /// Name of the box this storage reads and writes.
  ///
  /// Defaults to the name of [T], which is what makes one storage per type
  /// work without any wiring. Override it when two storages share a value
  /// type — two `LocalStorage<String>` subclasses would otherwise share one
  /// box, and clearing either would wipe the other.
  @protected
  String get boxName => T.toString();

  // Unique item key consists of the box name and some random characters
  // appended to it. Because it's important not to match with any other key
  // when another item is manually added.
  String get _uniqueItemKey => '$boxName-11ffbf9b510648da';

  /// Gets a single item in [T] type by [key] from the storage.
  @protected
  Future<T?> getSingle(String key) async {
    final box = await _getBox();
    final value = await box.get(key);
    // Return the value directly if it's null or primitive.
    if (value == null || _isTypePrimitive()) return value;
    // Deserialize the object's value and return it.
    final jsonMap = json.decode(value);
    return locator<T>(param1: jsonMap);
  }

  /// Adds a single [item] in [T] type into the storage.
  @protected
  Future<void> addSingle(T? item) async {
    final box = await _getBox();
    if (item == null || _isTypePrimitive()) {
      // Add the item into the box directly if it's null or primitive.
      await box.add(item);
    } else {
      // Serialize the item and add into the box as String.
      final jsonMap = (item as dynamic).toJson();
      final value = json.encode(jsonMap);
      await box.add(value);
    }
  }

  /// Adds a single [item] in [T] type into the storage after clearing all.
  @protected
  Future<void> addSingleAfterClear(T? item) async {
    await clearAll();
    return addSingle(item);
  }

  /// Adds or updates a single [item] in [T] type by [key] in the storage.
  @protected
  Future<void> putSingle(String key, T? item) async {
    final box = await _getBox();
    if (item == null || _isTypePrimitive()) {
      // Put the item into the box directly if it's null or primitive.
      await box.put(key, item);
    } else {
      // Serialize the item and add into the box as String.
      final jsonMap = (item as dynamic).toJson();
      final value = json.encode(jsonMap);
      await box.put(key, value);
    }
  }

  /// Removes a single item in [T] type by [key] from the storage.
  @protected
  Future<void> removeSingle(String key) async {
    final box = await _getBox();
    return box.delete(key);
  }

  /// Gets all the items in [T] type from the storage.
  @protected
  Future<Iterable<T?>> getAll() async {
    final box = await _getBox();
    final items = <T?>[];
    for (final key in box.keys) {
      final value = await box.get(key);
      if (value == null || _isTypePrimitive()) {
        // Add the value into the list directly if it's null or primitive.
        items.add(value);
      } else {
        // Deserialize the value and add into the list as object.
        final jsonMap = json.decode(value);
        final item = locator<T>(param1: jsonMap);
        items.add(item);
      }
    }
    return items;
  }

  /// Adds [items] in [T] type into the storage.
  @protected
  Future<void> addItems(Iterable<T?> items) async {
    for (final item in items) {
      await addSingle(item);
    }
  }

  /// Adds [items] in [T] type into the storage after clearing all.
  @protected
  Future<void> addItemsAfterClear(Iterable<T?> items) async {
    await clearAll();
    return addItems(items);
  }

  /// Removes items in [T] type by [keys] from the storage.
  @protected
  Future<void> removeItems(Iterable<String> keys) async {
    final box = await _getBox();
    return box.deleteAll(keys);
  }

  /// Clears all the items in [T] type in the storage.
  @protected
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Gets the unique item representing [T] type from the storage.
  @protected
  Future<T?> getUniqueItem() {
    return getSingle(_uniqueItemKey);
  }

  /// Updates the unique [item] representing [T] type in the storage.
  @protected
  Future<void> updateUniqueItem(T? item) {
    return putSingle(_uniqueItemKey, item);
  }

  /// Removes the unique [item] representing [T] type from the storage.
  @protected
  Future<void> removeUniqueItem() {
    return removeSingle(_uniqueItemKey);
  }

  static Future<void> dispose() {
    return Hive.close();
  }

  // Helpers
  Future<void> _initialize() async {
    try {
      if (_isInitialized) return;
      // Check if the encryption key exists in the secure storage.
      const secureStorage = FlutterSecureStorage();
      final encryptionKey = await secureStorage.read(
        key: _SecureStorageConstants.hiveEncryptionStorageKey,
        aOptions: _SecureStorageConstants.androidOptions,
        iOptions: _SecureStorageConstants.iosOptions,
      );
      // If the encryption key doesn't exist, generate and save a new one.
      if (encryptionKey == null) {
        final key = Hive.generateSecureKey();
        await secureStorage.write(
          key: _SecureStorageConstants.hiveEncryptionStorageKey,
          value: base64UrlEncode(key),
          aOptions: _SecureStorageConstants.androidOptions,
          iOptions: _SecureStorageConstants.iosOptions,
        );
      }
      // Initialize Hive. Saved encryption key will be used in unique storages.
      final appDocumentDir = await getApplicationDocumentsDirectory();
      Hive.init(appDocumentDir.path);
      _isInitialized = true;
    } catch (_) {}
  }

  Future<LazyBox<dynamic>> _getBox() async {
    await _initialize();
    // Return the box if it's already open.
    if (Hive.isBoxOpen(boxName)) {
      return Hive.lazyBox(boxName);
    }
    // Open a lazy box using encryption key fetched from secure storage.
    final key = await _secureStorage.read(
      key: _SecureStorageConstants.hiveEncryptionStorageKey,
      aOptions: _SecureStorageConstants.androidOptions,
      iOptions: _SecureStorageConstants.iosOptions,
    );
    final encryptionKey = base64Url.decode(key!);
    return Hive.openLazyBox(
      boxName,
      encryptionCipher: SecureHiveCipher(encryptionKey),
    );
  }

  bool _isTypePrimitive() =>
      T == int || T == double || T == bool || T == String;
  // - Helpers
}

abstract class _SecureStorageConstants {
  /// Storage key to save local storage encryption key generated by Hive.
  static const hiveEncryptionStorageKey = 'hiveEncryptionStorageKey';

  /// Secure storage Android options.
  static const androidOptions = AndroidOptions.defaultOptions;

  /// Secure storage iOS options.
  static const iosOptions = IOSOptions(
    // Fetch secure values while the app is backgrounded.
    accessibility: KeychainAccessibility.first_unlock,
  );
}
