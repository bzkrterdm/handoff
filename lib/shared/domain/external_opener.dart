/// Hands a location to the operating system: open a file in its default app
/// or reveal it in the file manager. Presentation depends on this interface;
/// the implementation (shelling out to `open`) lives in `shared/data`.
abstract class ExternalOpener {
  /// Opens [location] with the default application (Obsidian or the editor
  /// registered for `.md`).
  Future<void> open(String location);

  /// Shows [location] in Finder.
  Future<void> reveal(String location);
}
