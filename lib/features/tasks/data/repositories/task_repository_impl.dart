import 'dart:io';

import '../../../../stack/common/models/failure.dart';
import '../../../../stack/common/models/result.dart';
import '../../domain/entities/handoff_task.dart';
import '../../domain/entities/task_status.dart';
import '../../domain/repositories/task_repository.dart';
import '../data_sources/task_data_source.dart';
import '../models/task_model.dart';

/// Maps the data source's models and exceptions to entities and failures.
/// No exception escapes this class.
class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._dataSource);

  final TaskDataSource _dataSource;

  @override
  Future<Result<String, Failure>> getWorkspace() async {
    try {
      return Result.success(value: await _dataSource.location);
    } on Exception catch (error) {
      return Result.failure(Failure(message: error.toString()));
    }
  }

  @override
  Future<Result<String, Failure>> setWorkspace(String location) async {
    try {
      await _dataSource.setLocation(location);

      return Result.success(value: location);
    } on Exception catch (error) {
      return Result.failure(Failure(message: error.toString()));
    }
  }

  @override
  Future<Result<List<HandoffTask>, Failure>> getAll() async {
    try {
      final tasks =
          (await _dataSource.readAll())
              .map((model) => model.toEntity())
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return Result.success(value: tasks);
    } on FileSystemException catch (error) {
      return Result.failure(
        Failure(message: '${error.message}: ${error.path}'),
      );
    } on Exception catch (error) {
      return Result.failure(Failure(message: error.toString()));
    }
  }

  @override
  Stream<void> get onChanged => _dataSource.changes;

  @override
  Future<Result<HandoffTask, Failure>> setActionDone({
    required String taskId,
    required int index,
    required bool isDone,
  }) {
    return _guard(
      () => _dataSource.setActionDone(id: taskId, index: index, isDone: isDone),
    );
  }

  @override
  Future<Result<HandoffTask, Failure>> setStatus({
    required String taskId,
    required TaskStatus status,
  }) {
    return _guard(() => _dataSource.setStatus(id: taskId, status: status.key));
  }

  // Helpers
  Future<Result<HandoffTask, Failure>> _guard(
    Future<TaskModel> Function() write,
  ) async {
    try {
      final model = await write();

      return Result.success(value: model.toEntity());
    } on Exception catch (error) {
      return Result.failure(Failure(message: error.toString()));
    } on Error catch (error) {
      // RangeError / StateError from the data source are programming-level
      // but reachable from a stale screen; surface them, do not crash.
      return Result.failure(Failure(message: error.toString()));
    }
  }

  // - Helpers
}
