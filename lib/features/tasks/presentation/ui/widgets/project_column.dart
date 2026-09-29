import 'package:flutter/material.dart';

import '../../../../../shared/presentation/theme/app_theme.dart';
import '../../../../../shared/presentation/widgets/hover_surface.dart';
import '../../../../../stack/base/presentation/sub_view.dart';
import '../../../../../stack/core/localization/translate.dart';
import '../../../domain/entities/workspace_layout.dart';
import '../../blocs/tasks_cubit.dart';
import '../controllers/tasks_controller.dart';
import 'settings_menu.dart';

/// Left column: brand, every project that has tasks with its open count,
/// and the workspace folder at the bottom.
class ProjectColumn extends SubView<TasksController> {
  ProjectColumn({super.key, required this.state});

  final TasksLoaded state;

  @override
  Widget buildView(BuildContext context, TasksController controller) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final projects = state.projects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppLayout.titleBarHeight),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 14),
          child: Row(
            children: [
              const _BrandMark(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trt('title_app'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      trt(
                        'text_open_count_short',
                        namedArgs: {'count': '${state.openCount}'},
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: trt('button_refresh'),
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: controller.refresh,
              ),
              SettingsMenu(controller: controller),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 16, 6),
          child: Text(
            trt('text_projects').toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _ProjectRow(
                icon: Icons.inbox_outlined,
                label: trt('text_all_projects'),
                openCount: state.openCount,
                isSelected: state.selectedProject == TasksCubit.allProjects,
                onTap: () => controller.selectProject(TasksCubit.allProjects),
              ),
              const SizedBox(height: 6),
              for (final project in projects)
                _ProjectRow(
                  icon: Icons.folder_outlined,
                  label: project.key.isEmpty ? '—' : project.key,
                  openCount: project.openCount,
                  isSelected: state.selectedProject == project.key,
                  onTap: () => controller.selectProject(project.key),
                ),
            ],
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
        _WorkspaceFooter(
          workspace: state.workspace,
          onPick: () => controller.pickWorkspace(state.workspace),
          onOpen: () => controller.revealWorkspace(state.workspace),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.swap_calls_rounded,
        size: 18,
        color: Colors.white,
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.icon,
    required this.label,
    required this.openCount,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int openCount;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = isSelected
        ? scheme.onPrimaryContainer
        : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: HoverSurface(
        isSelected: isSelected,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (openCount > 0)
              _CountPill(count: openCount, emphasized: isSelected),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.emphasized});

  final int count;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: emphasized ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: emphasized ? scheme.onPrimary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _WorkspaceFooter extends StatelessWidget {
  const _WorkspaceFooter({
    required this.workspace,
    required this.onPick,
    required this.onOpen,
  });

  final String workspace;
  final VoidCallback onPick;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // The workspace is what the user picked; the task folder inside it is
    // an implementation detail.
    final name = WorkspaceLayout.rootNameOf(workspace);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: workspace,
              waitDuration: const Duration(milliseconds: 500),
              child: HoverSurface(
                onTap: onOpen,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_special_outlined,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trt('text_workspace'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Text(
                            name.isEmpty ? '—' : name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('pick_workspace'),
            tooltip: trt('button_choose_folder'),
            icon: const Icon(Icons.drive_folder_upload_outlined, size: 18),
            onPressed: onPick,
          ),
        ],
      ),
    );
  }
}
