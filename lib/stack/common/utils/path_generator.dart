import 'dart:io';

import 'package:android_path_provider/android_path_provider.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class PathGenerator {
  static String createFilePath({
    required String fileName,
    required String dirPath,
    bool increaseFileNameCount = true,
  }) {
    final filePath = '$dirPath/$fileName';
    return _updateFilePath(
      filePath,
      dirPath,
      increaseFileNameCount: increaseFileNameCount,
    );
  }

  static String createDownloadedFilePath({
    String? fileName,
    required String dirPath,
    required Headers headers,
    bool increaseFileNameCount = true,
  }) {
    if (fileName != null) {
      return createFilePath(
        fileName: fileName,
        dirPath: dirPath,
        increaseFileNameCount: increaseFileNameCount,
      );
    }
    return _getDownloadFilePath(
      headers,
      dirPath,
      increaseFileNameCount: increaseFileNameCount,
    );
  }

  static Future<String> getDownloadSaveDirectory() async {
    String? externalStorageDirPath;

    if (Platform.isAndroid) {
      try {
        externalStorageDirPath = await AndroidPathProvider.downloadsPath;
      } catch (err) {
        final externalStorateDir = await getExternalStorageDirectory();
        externalStorageDirPath = externalStorateDir?.path;
      }
    } else if (Platform.isIOS) {
      final documentsDir = await getApplicationDocumentsDirectory();
      externalStorageDirPath = documentsDir.absolute.path;
    }

    if (externalStorageDirPath == null) {
      throw Exception('Save directory not found');
    }

    return externalStorageDirPath;
  }

  static String _getDownloadFilePath(
    Headers headers,
    String dirPath, {
    required bool increaseFileNameCount,
  }) {
    final contentDisposition = headers.value('content-disposition');
    var fileName = contentDisposition
        ?.split(';')
        .firstWhereOrNull((e) => e.contains('filename'))
        ?.split('=')
        .last;

    fileName = fileName?.replaceAll('"', '');

    if (fileName != null) {
      return _updateFilePath(
        '$dirPath/$fileName',
        dirPath,
        increaseFileNameCount: increaseFileNameCount,
      );
    }
    throw Exception('File name could not be determined');
  }

  static String _updateFilePath(
    String filePath,
    String dirPath, {
    bool increaseFileNameCount = true,
  }) {
    const maximumFileLimit = 99;
    final pathWithoutExtension = filePath.substring(
      0,
      filePath.lastIndexOf('.'),
    );
    final extension = filePath.substring(
      filePath.lastIndexOf('.') + 1,
      filePath.length,
    );

    int? highestFileNumber;
    if (File(filePath).existsSync()) {
      for (var i = 1; i < maximumFileLimit; i++) {
        final newFilePath = '$pathWithoutExtension ($i).$extension';
        if (!File(newFilePath).existsSync()) {
          highestFileNumber = i - 1;
          break;
        }
      }
    }
    if (highestFileNumber != null) {
      //! This condition created for getting the right number
      //! when this method called in ApiResult.success
      highestFileNumber = increaseFileNameCount
          ? highestFileNumber + 1
          : highestFileNumber;

      if (highestFileNumber == 0) return filePath;

      return '$pathWithoutExtension ($highestFileNumber).$extension';
    }

    return filePath;
  }
}
