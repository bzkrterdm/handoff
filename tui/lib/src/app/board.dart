import 'package:handoff_core/handoff_core.dart';

/// Status helpers on the shared storage model, worded like the desktop
/// app's `HandoffTask`.
extension TaskView on TaskModel {
  /// Anything but `done` is open, so a typo never hides a task.
  bool get isDone => status.trim().toLowerCase() == 'done';

  bool get isOpen => !isDone;

  int get doneActionCount => actions.where((action) => action.isDone).length;

  /// Every item ticked; false when there is nothing to tick, so an
  /// informational task still needs an explicit close.
  bool get areAllActionsDone =>
      actions.isNotEmpty && doneActionCount == actions.length;
}

/// A project key with its counts, for the projects pane.
class ProjectSummary {
  const ProjectSummary({
    required this.key,
    required this.openCount,
    required this.totalCount,
  });

  final String key;
  final int openCount;
  final int totalCount;
}

/// The task list, the selected project and task, and the open/done filter —
/// one object, so the three panes always draw the same snapshot. The rules
/// are the desktop app's (`TasksLoaded` + `TasksCubit`): changing the
/// project or the filter selects the first visible task, a reload keeps the
/// selection when the task survived.
class Board {
  /// Key of the pseudo project that shows every task.
  static const String allProjects = '*';

  /// Every task, newest first.
  List<TaskModel> tasks = const [];

  String selectedProject = allProjects;
  String? selectedTaskId;

  /// Whether the list shows closed tasks instead of open ones.
  bool showDone = false;

  /// Project keys with their open counts, sorted by key. Projects with no
  /// open task stay, so a done task can still be found under them.
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

  /// The project pane's rows: "all projects" first.
  List<String> get projectKeys => [
    allProjects,
    for (final project in projects) project.key,
  ];

  int get openCount => tasks.where((task) => task.isOpen).length;

  int countFor({required bool done}) {
    return tasks
        .where((task) => _inProject(task) && task.isDone == done)
        .length;
  }

  /// The list pane: tasks of the selected project and status.
  List<TaskModel> get visibleTasks => tasks
      .where((task) => _inProject(task) && task.isDone == showDone)
      .toList();

  TaskModel? get selectedTask {
    for (final task in tasks) {
      if (task.id == selectedTaskId) return task;
    }

    return null;
  }

  /// Takes a fresh read of the store.
  void load(List<TaskModel> fresh) {
    tasks = [...fresh]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (selectedProject != allProjects &&
        !tasks.any((task) => task.project == selectedProject)) {
      selectedProject = allProjects;
    }
    if (selectedTask == null) _selectFirst();
  }

  /// Applies a task the store just returned from a write, so the change is
  /// on screen before the watcher's reload lands.
  void replace(TaskModel updated) {
    tasks = [for (final task in tasks) task.id == updated.id ? updated : task];
  }

  void selectProject(String project) {
    selectedProject = project;
    _selectFirst();
  }

  void selectTask(String? id) => selectedTaskId = id;

  void setShowDone(bool value) {
    if (showDone == value) return;
    showDone = value;
    _selectFirst();
  }

  /// Moves the selection [delta] rows in the visible list.
  void moveSelection(int delta) {
    final visible = visibleTasks;
    if (visible.isEmpty) return;
    final index = visible.indexWhere((task) => task.id == selectedTaskId);
    final next = (index < 0 ? 0 : index + delta).clamp(0, visible.length - 1);
    selectedTaskId = visible[next].id;
  }

  // Helpers
  bool _inProject(TaskModel task) =>
      selectedProject == allProjects || task.project == selectedProject;

  void _selectFirst() {
    final visible = visibleTasks;
    selectedTaskId = visible.isEmpty ? null : visible.first.id;
  }

  // - Helpers
}
