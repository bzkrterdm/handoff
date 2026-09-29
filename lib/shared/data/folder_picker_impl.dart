import 'package:file_selector/file_selector.dart';

import '../domain/folder_picker.dart';

class FolderPickerImpl implements FolderPicker {
  @override
  Future<String?> pick({String? initialDirectory, String? title}) {
    return getDirectoryPath(
      initialDirectory: initialDirectory,
      confirmButtonText: title,
    );
  }
}
