import '../models/task_model.dart';

/// What a task store has to provide. `MarkdownTaskDataSource` reads a
/// folder; a `SupabaseTaskDataSource` will read a table. The repository only
/// ever sees this interface.
abstract class TaskDataSource {
  /// Where the store lives, for display: a folder path today, a project url
  /// later.
  Future<String> get location;

  /// Points the store somewhere else and remembers it.
  Future<void> setLocation(String location);

  /// Every task the store holds, in no particular order.
  Future<List<TaskModel>> readAll();

  /// Fires after the store changed. The repository turns it into
  /// `TaskRepository.onChanged`.
  Stream<void> get changes;

  /// Ticks or unticks the [index]th action of task [id]; returns the stored
  /// task afterwards. Throws when the task or the index does not exist.
  Future<TaskModel> setActionDone({
    required String id,
    required int index,
    required bool isDone,
  });

  /// Sets the status of task [id] (`open` / `done`), stamps `closed_at` when
  /// closing and clears it when reopening; returns the stored task.
  Future<TaskModel> setStatus({required String id, required String status});

  /// Releases watchers and handles.
  Future<void> dispose();
}
