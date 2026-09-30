import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../../stack/base/domain/use_case.dart';
import '../../../../stack/base/presentation/safe_cubit.dart';
import '../../../../stack/common/mixins/use_case_cancel_mixin.dart';
import '../../../../stack/common/models/failure.dart';
import '../../../../stack/common/models/result.dart';
import '../../domain/entities/handoff_task.dart';
import '../../domain/entities/task_snapshot.dart';
import '../../domain/entities/task_status.dart';
import '../../domain/use_cases/set_action_done.dart';
import '../../domain/use_cases/set_task_status.dart';
import '../../domain/use_cases/set_workspace.dart';
import '../../domain/use_cases/watch_tasks.dart';

part 'tasks_state.dart';

/// Owns the task list, the selection and the open/done filter.
///
/// The list is fed by a stream use case, so a file an agent writes shows up
/// without a refresh; writes go through use cases and the store answers with
/// a change event, which reloads the list — the cubit never patches its own
/// copy, so what is on screen is always what is on disk.
class TasksCubit extends SafeCubit<TasksState> with UseCaseCancelMixin {
  TasksCubit(
    this._watchTasks,
    this._setActionDone,
    this._setTaskStatus,
    this._setWorkspace,
  ) : super(const TasksInitial());

  /// Key of the pseudo project that shows every task.
  static const String allProjects = '*';

  final WatchTasks _watchTasks;
  final SetActionDone _setActionDone;
  final SetTaskStatus _setTaskStatus;
  final SetWorkspace _setWorkspace;
  String _workspace = '';
  StreamSubscription<Result<TaskSnapshot, Failure>>? _subscription;

  @override
  List<UseCase<dynamic, dynamic, dynamic>> get useCasesToCancel => [
    _setActionDone,
    _setTaskStatus,
    _setWorkspace,
  ];

  /// Starts (or restarts) following the store.
  Future<void> start() async {
    await _subscription?.cancel();
    emit(const TasksLoading());
    _subscription = _watchTasks().listen(_onTasks);
  }

  /// Points the app at another folder and reloads from it.
  Future<void> changeWorkspace(String path) async {
    final result = await _setWorkspace(params: path);
    switch (result) {
      case Success():
        await start();
      case Failed(:final error):
        final current = state;
        if (current is TasksLoaded) {
          emit(current.copyWith(lastError: () => error.message));
        } else {
          // First start or an already failed folder: there is no list to
          // toast over, so show the error page for the folder that was
          // just picked instead of swallowing the failure.
          emit(TasksError(message: error.message, workspace: path));
        }
    }
  }

  void selectProject(String project) {
    final current = state;
    if (current is! TasksLoaded) return;

    final next = current.copyWith(selectedProject: project);
    emit(next.copyWith(selectedTaskId: () => _firstVisibleId(next)));
  }

  void selectTask(String? taskId) {
    final current = state;
    if (current is! TasksLoaded) return;

    emit(current.copyWith(selectedTaskId: () => taskId));
  }

  void showDone({required bool showDone}) {
    final current = state;
    if (current is! TasksLoaded || current.showDone == showDone) return;

    final next = current.copyWith(showDone: showDone);
    emit(next.copyWith(selectedTaskId: () => _firstVisibleId(next)));
  }

  Future<void> setActionDone({
    required String taskId,
    required int index,
    required bool isDone,
  }) async {
    final result = await _setActionDone(
      params: SetActionDoneParams(taskId: taskId, index: index, isDone: isDone),
    );
    _reportWrite(result);
  }

  Future<void> setStatus({
    required String taskId,
    required TaskStatus status,
  }) async {
    final result = await _setTaskStatus(
      params: SetTaskStatusParams(taskId: taskId, status: status),
    );
    _reportWrite(result);
  }

  /// Applies a task the store just returned, so the change is visible before
  /// the watcher's reload lands.
  void _reportWrite(Result<HandoffTask, Failure> result) {
    final current = state;
    if (current is! TasksLoaded) return;

    switch (result) {
      case Success(:final value?):
        emit(current.copyWith(tasks: _replace(current.tasks, value)));
      case Success():
        break;
      case Failed(:final error):
        emit(current.copyWith(lastError: () => error.message));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _watchTasks.stop();
    cancelUseCases();

    return super.close();
  }

  // Helpers
  void _onTasks(Result<TaskSnapshot, Failure> result) {
    final current = state;
    switch (result) {
      case Success(:final value):
        final tasks = value?.tasks ?? const <HandoffTask>[];
        _workspace = value?.workspace ?? _workspace;
        if (value?.error case final error?) {
          emit(TasksError(message: error.message, workspace: _workspace));
        } else if (current is TasksLoaded) {
          final next = current.copyWith(tasks: tasks, workspace: _workspace);
          // Keep the selection when it survived the reload, otherwise land on
          // the first visible task so the detail column is never stale.
          final stillThere = next.selectedTask != null;
          emit(
            stillThere
                ? next
                : next.copyWith(selectedTaskId: () => _firstVisibleId(next)),
          );
        } else {
          final next = TasksLoaded(tasks: tasks, workspace: _workspace);
          emit(next.copyWith(selectedTaskId: () => _firstVisibleId(next)));
        }
      case Failed(:final error):
        emit(TasksError(message: error.message, workspace: _workspace));
    }
  }

  String? _firstVisibleId(TasksLoaded state) {
    final visible = state.visibleTasks;

    return visible.isEmpty ? null : visible.first.id;
  }

  List<HandoffTask> _replace(List<HandoffTask> tasks, HandoffTask updated) {
    return [for (final task in tasks) task.id == updated.id ? updated : task];
  }

  // - Helpers
}
