import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/stack/common/utils/path_generator.dart';

void main() {
  group('PathGenerator', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('handoff_files');
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test('createFilePath keeps the name when nothing is there', () {
      final path = PathGenerator.createFilePath(
        fileName: 'report.pdf',
        dirPath: directory.path,
      );

      expect(path, '${directory.path}/report.pdf');
    });

    test('createFilePath numbers a name that is taken', () {
      File('${directory.path}/report.pdf').writeAsStringSync('first');

      final path = PathGenerator.createFilePath(
        fileName: 'report.pdf',
        dirPath: directory.path,
      );

      expect(path, '${directory.path}/report (1).pdf');
    });

    test('createFilePath can overwrite instead of numbering', () {
      File('${directory.path}/report.pdf').writeAsStringSync('first');

      final path = PathGenerator.createFilePath(
        fileName: 'report.pdf',
        dirPath: directory.path,
        increaseFileNameCount: false,
      );

      expect(path, '${directory.path}/report.pdf');
    });
  });
}
