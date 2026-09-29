import '../../../../stack/common/models/failure.dart';
import '../../../../stack/common/models/result.dart';
import '../entities/handoff_task.dart';
import '../entities/task_status.dart';

/// The contract the presentation layer depends on. Where the tasks come from
/// (markdown files in a workspace folder today, Supabase later) is a data
/// layer detail behind this interface: swapping the store means swapping one
/// registration in `DependencyConfig`, nothing above this line changes.
abstract class TaskRepository {
  /// Where the store lives, for display and for the folder picker.
  Future<Result<String, Failure>> getWorkspace();

  /// Points the store at another workspace and remembers it. Emits on
  /// [onChanged] afterwards.
  Future<Result<String, Failure>> setWorkspace(String location);

  /// Every task in the store, newest first.
  Future<Result<List<HandoffTask>, Failure>> getAll();

  /// Emits whenever the store changes underneath the app — a file written by
  /// an agent, a checkbox ticked in Obsidian, later a realtime row change.
  /// Listeners reload with [getAll]; the event carries no payload on purpose,
  /// so every store can provide it.
  Stream<void> get onChanged;

  /// Ticks or unticks the [index]th expected item of [taskId] and returns the
  /// task as stored afterwards.
  Future<Result<HandoffTask, Failure>> setActionDone({
    required String taskId,
    required int index,
    required bool isDone,
  });

  /// Opens or closes [taskId] and returns the task as stored afterwards.
  Future<Result<HandoffTask, Failure>> setStatus({
    required String taskId,
    required TaskStatus status,
  });
}
