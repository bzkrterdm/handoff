/// Lets the owner choose a folder with the system dialog.
abstract class FolderPicker {
  /// The chosen absolute path, or null when the dialog was dismissed.
  Future<String?> pick({String? initialDirectory, String? title});
}
