import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/presentation/theme/app_theme.dart';
import '../../../../../shared/presentation/widgets/empty_state.dart';
import '../../../../../stack/base/presentation/controlled_view.dart';
import '../../../../../stack/core/localization/translate.dart';
import '../../blocs/tasks_cubit.dart';
import '../controllers/tasks_controller.dart';
import '../widgets/project_column.dart';
import '../widgets/task_detail_column.dart';
import '../widgets/task_list_column.dart';

/// The whole app on one page: projects on the left, the tasks of the chosen
/// project in the middle, the chosen task on the right. The widget lays the
/// columns out; every decision goes through [TasksController].
class TasksPage extends ControlledView<TasksController, Object> {
  TasksPage({super.key, super.params});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<TasksCubit, TasksState>(
        listener: _onStateChanged,
        builder: (context, state) => switch (state) {
          TasksInitial() || TasksLoading() => const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          TasksError(:final message, :final workspace) => _ErrorView(
            message: message,
            workspace: workspace,
            onRetry: controller.refresh,
            onPickFolder: () => controller.pickWorkspace(workspace),
          ),
          TasksLoaded() => _Columns(state: state),
        },
      ),
    );
  }
}

extension on TasksPage {
  /// Side effects of a state change: the Dock badge and failed-write toasts.
  void _onStateChanged(BuildContext context, TasksState state) {
    if (state is TasksLoaded) {
      controller.onOpenCountChanged(state.openCount);
      final error = state.lastError;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } else if (state is TasksError) {
      controller.onOpenCountChanged(0);
    }
  }
}

class _Columns extends StatelessWidget {
  const _Columns({required this.state});

  final TasksLoaded state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: AppLayout.sidebarWidth,
          color: scheme.surfaceContainerLow,
          child: ProjectColumn(state: state),
        ),
        const VerticalDivider(),
        SizedBox(
          width: AppLayout.listWidth,
          child: TaskListColumn(state: state),
        ),
        const VerticalDivider(),
        Expanded(child: TaskDetailColumn(task: state.selectedTask)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.workspace,
    required this.onRetry,
    required this.onPickFolder,
  });

  final String message;
  final String workspace;
  final VoidCallback onRetry;
  final VoidCallback onPickFolder;

  @override
  Widget build(BuildContext context) {
    // No folder yet is the first start, not a failure.
    final isFirstStart = workspace.isEmpty;

    return EmptyState(
      icon: isFirstStart
          ? Icons.waving_hand_outlined
          : Icons.folder_off_outlined,
      title: trt(isFirstStart ? 'text_welcome' : 'text_error_load'),
      hint: isFirstStart ? trt('text_welcome_hint') : message,
      action: Wrap(
        spacing: 8,
        children: [
          FilledButton.icon(
            onPressed: onPickFolder,
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: Text(trt('button_choose_folder')),
          ),
          if (!isFirstStart)
            OutlinedButton(
              onPressed: onRetry,
              child: Text(trt('button_retry')),
            ),
        ],
      ),
    );
  }
}
