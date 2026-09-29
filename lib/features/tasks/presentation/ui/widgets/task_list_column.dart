import 'package:flutter/material.dart';

import '../../../../../shared/presentation/format/date_text.dart';
import '../../../../../shared/presentation/theme/app_theme.dart';
import '../../../../../shared/presentation/widgets/agent_avatar.dart';
import '../../../../../shared/presentation/widgets/empty_state.dart';
import '../../../../../shared/presentation/widgets/hover_surface.dart';
import '../../../../../shared/presentation/widgets/progress_bar.dart';
import '../../../../../stack/base/presentation/sub_view.dart';
import '../../../../../stack/core/localization/translate.dart';
import '../../../domain/entities/handoff_task.dart';
import '../../blocs/tasks_cubit.dart';
import '../controllers/tasks_controller.dart';

/// Middle column: the open (or done) tasks of the selected project as cards.
class TaskListColumn extends SubView<TasksController> {
  TaskListColumn({super.key, required this.state});

  final TasksLoaded state;

  @override
  Widget buildView(BuildContext context, TasksController controller) {
    final theme = Theme.of(context);
    final tasks = state.visibleTasks;
    final heading = state.selectedProject == TasksCubit.allProjects
        ? trt('text_all_projects')
        : state.selectedProject;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppLayout.titleBarHeight),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  heading,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text(trt('tab_open'))),
                  ButtonSegment(value: true, label: Text(trt('tab_done'))),
                ],
                selected: {state.showDone},
                onSelectionChanged: (selection) =>
                    controller.showDone(showDone: selection.first),
              ),
            ],
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? EmptyState(
                  icon: state.showDone
                      ? Icons.task_alt_rounded
                      : Icons.inbox_outlined,
                  title: trt(
                    state.showDone
                        ? 'text_no_tasks_done'
                        : 'text_no_tasks_open',
                  ),
                  hint: trt(
                    state.showDone
                        ? 'text_no_tasks_done_hint'
                        : 'text_no_tasks_open_hint',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) => TaskCard(
                    task: tasks[index],
                    showProject:
                        state.selectedProject == TasksCubit.allProjects,
                    isSelected: tasks[index].id == state.selectedTaskId,
                    onTap: () => controller.selectTask(tasks[index].id),
                  ),
                ),
        ),
      ],
    );
  }
}

/// One card of the list: title, project when the list spans projects, agent,
/// date and checklist progress.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.showProject,
    required this.isSelected,
    required this.onTap,
  });

  final HandoffTask task;
  final bool showProject;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return HoverSurface(
      isSelected: isSelected,
      showBorder: true,
      radius: AppLayout.radius,
      selectedColor: scheme.primaryContainer.withValues(alpha: 0.45),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AgentAvatar(agent: task.agent, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  showProject
                      ? '${task.agent}  ·  ${task.project}'
                      : task.agent,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ),
              const SizedBox(width: 8),
              Text(DateText.relative(task.createdAt), style: muted),
            ],
          ),
          if (task.actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ProgressBar(
                    done: task.doneActionCount,
                    total: task.actions.length,
                    height: 4,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${task.doneActionCount}/${task.actions.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
