import 'dart:async';

import '../../../../stack/base/domain/use_case.dart';
import '../../../../stack/common/models/failure.dart';
import '../../../../stack/common/models/result.dart';
import '../entities/task_snapshot.dart';
import '../repositories/task_repository.dart';

/// Loads the tasks once, then again after every change in the store, so the
/// list on screen follows what agents and the owner write to the workspace.
///
/// Built on a controller rather than an `async*` body on purpose: a generator
/// suspended in `await for` over the change stream cannot be cancelled until
/// the next change arrives, which made the cubit's `close()` hang.
class WatchTasks extends StreamUseCase<void, TaskSnapshot, void> {
  WatchTasks(super.logger, this._repository);

  final TaskRepository _repository;
  StreamController<Result<TaskSnapshot, Failure>>? _controller;
  StreamSubscription<void>? _changes;

  @override
  Stream<Result<TaskSnapshot, Failure>> call({void params}) {
    final controller = StreamController<Result<TaskSnapshot, Failure>>(
      onListen: _start,
      onCancel: stop,
    );
    _controller = controller;

    return controller.stream;
  }

  @override
  Future<void> stop() async {
    await _changes?.cancel();
    _changes = null;
    await _controller?.close();
    _controller = null;
    await super.stop();
  }

  // Helpers
  Future<void> _start() async {
    await _reload();
    _changes = _repository.onChanged.listen((_) => _reload());
  }

  Future<void> _reload() async {
    final workspace = await _repository.getWorkspace();
    final tasks = await _repository.getAll();
    final controller = _controller;
    if (controller == null || controller.isClosed) return;

    controller.add(switch ((workspace, tasks)) {
      (Success(value: final location), Success(value: final list)) =>
        Result.success(
          value: TaskSnapshot(workspace: location ?? '', tasks: list ?? []),
        ),
      (Success(value: final location), Failed(:final error)) => Result.success(
        value: TaskSnapshot(workspace: location ?? '', error: error),
      ),
      (Failed(:final error), _) => Result.failure(error),
    });
  }

  // - Helpers
}
