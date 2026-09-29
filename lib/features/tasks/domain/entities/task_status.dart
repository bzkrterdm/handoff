/// Lifecycle of a handoff task. A task is open while the owner still has
/// something to do about it and done once they (or a later agent) close it.
enum TaskStatus {
  open,
  done;

  /// The value written to the task file and, later, the database column.
  String get key => name;

  /// Parses a stored value; anything unknown is treated as open, so that a
  /// typo in a hand-written file never hides a task.
  static TaskStatus parse(Object? value) {
    return value?.toString().trim().toLowerCase() == done.key ? done : open;
  }
}
