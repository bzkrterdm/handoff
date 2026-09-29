/// Writes the number shown on the app's Dock icon. Null or zero clears it.
abstract class DockBadge {
  Future<void> setCount(int count);
}
