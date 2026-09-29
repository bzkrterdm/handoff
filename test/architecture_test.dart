import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Clean architecture layer rules, checked without the analyzer plugin.
///
/// `dart_code_linter`'s `avoid-banned-imports` enforces the same rules while
/// editing, but only as long as the plugin is actually running. This test is
/// the copy that cannot silently stop working: it reads the imports straight
/// off the source files, so a violation fails `flutter test` and CI too.
void main() {
  final files = _readLibraryFiles();

  test('there are library files to check', () {
    expect(files, isNotEmpty);
  });

  group('domain layer', () {
    test('does not reference Flutter', () {
      // The stack's own base classes are exempt: they are framework code and
      // use foundation only for annotations such as @protected.
      final offenders = _offenders(
        files,
        inLayer: 'domain',
        where: (uri) => uri.startsWith('package:flutter/'),
        skipPath: (path) => path.startsWith('lib/stack/'),
      );

      expect(offenders, isEmpty, reason: _reason(offenders));
    });

    test('does not reference the data or presentation layers', () {
      final offenders = _offenders(
        files,
        inLayer: 'domain',
        where: (uri) =>
            uri.contains('/data/') || uri.contains('/presentation/'),
      );

      expect(offenders, isEmpty, reason: _reason(offenders));
    });
  });

  group('presentation layer', () {
    test('does not reference the data layer', () {
      final offenders = _offenders(
        files,
        inLayer: 'presentation',
        where: (uri) => uri.contains('/data/'),
      );

      expect(offenders, isEmpty, reason: _reason(offenders));
    });
  });

  group('data layer', () {
    test('does not reference the presentation layer', () {
      final offenders = _offenders(
        files,
        inLayer: 'data',
        where: (uri) => uri.contains('/presentation/'),
      );

      expect(offenders, isEmpty, reason: _reason(offenders));
    });
  });
}

/// A source file and the uris it imports or exports.
class _LibraryFile {
  const _LibraryFile({required this.path, required this.directives});

  static final RegExp _directive = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  );

  final String path;
  final List<String> directives;

  /// Whether the file sits anywhere under a [layer] directory.
  bool isInLayer(String layer) => path.contains('/$layer/');
}

List<_LibraryFile> _readLibraryFiles() {
  final directory = Directory('lib');
  if (!directory.existsSync()) return const [];

  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) {
        final directives = file
            .readAsLinesSync()
            .map(_LibraryFile._directive.firstMatch)
            .nonNulls
            .map((match) => match.group(1)!)
            .toList();

        return _LibraryFile(path: file.path, directives: directives);
      })
      .toList();
}

List<String> _offenders(
  List<_LibraryFile> files, {
  required String inLayer,
  required bool Function(String uri) where,
  bool Function(String path)? skipPath,
}) {
  final offenders = <String>[];
  for (final file in files) {
    if (!file.isInLayer(inLayer)) continue;
    if (skipPath?.call(file.path) == true) continue;
    for (final uri in file.directives.where(where)) {
      offenders.add('${file.path} -> $uri');
    }
  }
  return offenders;
}

String _reason(List<String> offenders) {
  return 'Layer rule violated by:\n${offenders.join('\n')}';
}
