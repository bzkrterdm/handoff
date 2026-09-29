import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/domain/agent_launcher.dart';
import '../../../../../shared/domain/agent_prompt.dart';
import '../../../../../shared/domain/dock_badge.dart';
import '../../../../../shared/domain/external_opener.dart';
import '../../../../../shared/domain/folder_picker.dart';
import '../../../../../shared/presentation/tasks/confirm_task.dart';
import '../../../../../stack/base/presentation/controller.dart';
import '../../../../../stack/core/theme/theme_manager.dart';
import '../../../domain/entities/handoff_task.dart';
import '../../../domain/entities/task_status.dart';
import '../../blocs/tasks_cubit.dart';

/// Presentation logic of the task board. The page forwards input here; the
/// decisions (confirmations, what to open, the Dock badge) are made here.
class TasksController extends Controller<Object> {
  TasksController(
    super.logger,
    super.localizor,
    super.routeManager,
    super.popupManager,
    this._confirmTask,
    this._externalOpener,
    this._folderPicker,
    this._dockBadge,
    this._agentLauncher,
    this._themeManager,
  );

  static const _reopenParams = ConfirmParams(
    messageKey: 'text_confirm_reopen',
    confirmKey: 'button_reopen',
  );

  final ConfirmTask _confirmTask;
  final ExternalOpener _externalOpener;
  final FolderPicker _folderPicker;
  final DockBadge _dockBadge;
  final AgentLauncher _agentLauncher;
  final ThemeManager _themeManager;

  @override
  void onReady() {
    super.onReady();
    _cubit.start();
  }

  void refresh() => _cubit.start();

  /// Called by the page whenever the open count may have changed.
  void onOpenCountChanged(int count) => _dockBadge.setCount(count);

  void selectProject(String project) => _cubit.selectProject(project);

  void selectTask(String taskId) => _cubit.selectTask(taskId);

  void showDone({required bool showDone}) =>
      _cubit.showDone(showDone: showDone);

  void toggleAction(HandoffTask task, int index, {required bool isDone}) {
    _cubit.setActionDone(taskId: task.id, index: index, isDone: isDone);
  }

  void closeTask(HandoffTask task) {
    _cubit.setStatus(taskId: task.id, status: TaskStatus.done);
  }

  Future<void> reopenTask(HandoffTask task) async {
    final isConfirmed = await _confirmTask.execute(
      context,
      params: _reopenParams,
    );
    if (isConfirmed != true || !isActive) return;

    await _cubit.setStatus(taskId: task.id, status: TaskStatus.open);
  }

  /// The language on screen right now.
  Locale get currentLocale => localizor.getLocale(context);

  /// Whether the app follows the device language (no explicit choice).
  bool get followsDeviceLanguage => localizor.getSavedLocale(context) == null;

  ThemeMode get currentThemeMode => _themeManager.currentThemeMode(context);

  /// Switches the UI language; null means "follow the device".
  Future<void> changeLanguage(Locale? locale) {
    return locale == null
        ? localizor.useDeviceLocale(context)
        : localizor.changeLocale(context, locale);
  }

  void changeAppearance(ThemeMode mode) {
    _themeManager.changeThemeMode(context, mode);
  }

  /// Lets the owner point the app at another workspace folder.
  Future<void> pickWorkspace(String current) async {
    final path = await _folderPicker.pick(
      initialDirectory: current.isEmpty ? null : current,
      title: localizor.tr('button_choose_folder'),
    );
    if (path == null || !isActive) return;

    await _cubit.changeWorkspace(path);
  }

  /// Opens a terminal with the task's agent started in the task's folder and
  /// a first message that points it at the task file. With [focus] the
  /// message is about that one checklist item only: the agent is told not
  /// to go through the other items.
  Future<void> connectAgent(HandoffTask task, {String? focus}) async {
    final cwd = task.workingDirectory;
    if (cwd == null) return;

    final path = task.location ?? task.id;
    final prompt = focus == null
        ? AgentPrompt.forTask(title: task.title, path: path)
        : AgentPrompt.forItem(title: task.title, path: path, item: focus);
    logger.info(
      'Connecting ${task.agent} for ${task.id}'
      '${task.sessionId == null ? '' : ' (resume)'}',
      callerType: runtimeType,
    );
    await _agentLauncher.launch(
      AgentLaunch(
        agent: task.agent,
        workingDirectory: cwd,
        prompt: prompt,
        sessionId: task.sessionId,
      ),
    );
  }

  Future<void> openTaskFile(HandoffTask task) async {
    final location = task.location;
    if (location == null) return;

    await _externalOpener.open(location);
  }

  Future<void> revealTaskFile(HandoffTask task) async {
    final location = task.location;
    if (location == null) return;

    await _externalOpener.reveal(location);
  }

  Future<void> revealWorkspace(String workspace) async {
    if (workspace.isEmpty) return;

    await _externalOpener.open(workspace);
  }

  // Helpers
  TasksCubit get _cubit => context.read<TasksCubit>();

  // - Helpers
}
