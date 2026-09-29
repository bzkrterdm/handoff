part of 'tasks_cubit.dart';

sealed class TasksState extends Equatable {
  const TasksState();

  @override
  List<Object?> get props => [];
}

class TasksInitial extends TasksState {
  const TasksInitial();
}

class TasksLoading extends TasksState {
  const TasksLoading();
}

/// The store was read. Selection and filter live here too, so the three
/// columns always derive from one consistent snapshot.
class TasksLoaded extends TasksState {
  const TasksLoaded({
    required this.tasks,
    this.workspace = '',
    this.selectedProject = TasksCubit.allProjects,
    this.selectedTaskId,
    this.showDone = false,
    this.lastError,
  });

  /// Every task, newest first.
  final List<HandoffTask> tasks;

  /// The folder (or, later, the remote location) the tasks come from.
  final String workspace;

  /// Project key or [TasksCubit.allProjects].
  final String selectedProject;

  final String? selectedTaskId;

  /// Whether the list shows closed tasks instead of open ones.
  final bool showDone;

  /// A write that failed after a successful load; shown once and cleared.
  final String? lastError;

  /// Project keys with their open counts, sorted by key. Projects with no
  /// open task are kept so a done task can still be found under them.
  List<ProjectSummary> get projects {
    final open = <String, int>{};
    final total = <String, int>{};
    for (final task in tasks) {
      total.update(task.project, (n) => n + 1, ifAbsent: () => 1);
      if (task.isOpen) {
        open.update(task.project, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final keys = total.keys.toList()..sort();

    return [
      for (final key in keys)
        ProjectSummary(
          key: key,
          openCount: open[key] ?? 0,
          totalCount: total[key]!,
        ),
    ];
  }

  int get openCount => tasks.where((task) => task.isOpen).length;

  /// The middle column: tasks of the selected project and status.
  List<HandoffTask> get visibleTasks {
    return tasks.where((task) {
      final inProject =
          selectedProject == TasksCubit.allProjects ||
          task.project == selectedProject;

      return inProject && task.isDone == showDone;
    }).toList();
  }

  HandoffTask? get selectedTask {
    for (final task in tasks) {
      if (task.id == selectedTaskId) return task;
    }

    return null;
  }

  TasksLoaded copyWith({
    List<HandoffTask>? tasks,
    String? workspace,
    String? selectedProject,
    String? Function()? selectedTaskId,
    bool? showDone,
    String? Function()? lastError,
  }) {
    return TasksLoaded(
      tasks: tasks ?? this.tasks,
      workspace: workspace ?? this.workspace,
      selectedProject: selectedProject ?? this.selectedProject,
      selectedTaskId: selectedTaskId != null
          ? selectedTaskId()
          : this.selectedTaskId,
      showDone: showDone ?? this.showDone,
      lastError: lastError != null ? lastError() : null,
    );
  }

  @override
  List<Object?> get props => [
    tasks,
    workspace,
    selectedProject,
    selectedTaskId,
    showDone,
    lastError,
  ];
}

class TasksError extends TasksState {
  const TasksError({required this.message, this.workspace = ''});

  final String message;

  /// Shown with the error so the owner can see (and change) which folder
  /// failed.
  final String workspace;

  @override
  List<Object?> get props => [message, workspace];
}

class ProjectSummary extends Equatable {
  const ProjectSummary({
    required this.key,
    required this.openCount,
    required this.totalCount,
  });

  final String key;
  final int openCount;
  final int totalCount;

  @override
  List<Object?> get props => [key, openCount, totalCount];
}
