import 'package:flutter/material.dart';

import '../../../../../shared/presentation/format/date_text.dart';
import '../../../../../shared/presentation/theme/app_theme.dart';
import '../../../../../shared/presentation/widgets/agent_avatar.dart';
import '../../../../../shared/presentation/widgets/empty_state.dart';
import '../../../../../shared/presentation/widgets/markdown_text.dart';
import '../../../../../shared/presentation/widgets/progress_bar.dart';
import '../../../../../stack/base/presentation/sub_view.dart';
import '../../../../../stack/core/localization/translate.dart';
import '../../../domain/entities/handoff_task.dart';
import '../../../domain/entities/task_action.dart';
import '../controllers/tasks_controller.dart';

/// Right column: the selected task in full, with the owner's checklist.
class TaskDetailColumn extends SubView<TasksController> {
  TaskDetailColumn({super.key, required this.task});

  final HandoffTask? task;

  @override
  Widget buildView(BuildContext context, TasksController controller) {
    final task = this.task;
    if (task == null) {
      return EmptyState(
        icon: Icons.article_outlined,
        title: trt('text_select_task'),
        hint: trt('text_select_task_hint'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppLayout.titleBarHeight),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                key: ValueKey(task.id),
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                children: [
                  _Header(task: task, controller: controller),
                  const SizedBox(height: 24),
                  _ChecklistCard(task: task, controller: controller),
                  if (task.summary.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _SectionCard(
                      icon: Icons.check_circle_outline,
                      title: trt('section_summary'),
                      child: MarkdownText(task.summary),
                    ),
                  ],
                  if (task.info.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _SectionCard(
                      icon: Icons.info_outline,
                      title: trt('section_info'),
                      child: MarkdownText(task.info),
                    ),
                  ],
                  if (task.related.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _SectionCard(
                      icon: Icons.link_rounded,
                      title: trt('text_related'),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final id in task.related) _Tag(label: id),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.task, required this.controller});

  final HandoffTask task;
  final TasksController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final closedAt = task.closedAt;
    final closedText = closedAt == null ? '' : DateText.full(closedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder_outlined, size: 14, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              task.project,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
            if (task.isDone) ...[
              const SizedBox(width: 10),
              _Tag(
                label: '${trt('text_closed_at')} · $closedText',
                tone: _TagTone.success,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(task.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 10),
        Row(
          children: [
            AgentAvatar(agent: task.agent, size: 20),
            const SizedBox(width: 6),
            Text(task.agent, style: muted),
            Text('  ·  ', style: muted),
            Text(DateText.full(task.createdAt), style: muted),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (task.isOpen)
              FilledButton.icon(
                key: const Key('close_task'),
                onPressed: () => controller.closeTask(task),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(trt('button_close_task')),
              )
            else
              OutlinedButton.icon(
                key: const Key('reopen_task'),
                onPressed: () => controller.reopenTask(task),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: Text(trt('button_reopen')),
              ),
            if (task.workingDirectory != null)
              OutlinedButton.icon(
                key: const Key('connect_agent'),
                onPressed: () => controller.connectAgent(task),
                icon: const Icon(Icons.terminal_rounded, size: 18),
                label: Text(trt('button_connect_agent')),
              ),
            if (task.location != null) ...[
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () => controller.openTaskFile(task),
                icon: const Icon(Icons.description_outlined, size: 17),
                label: Text(trt('button_open_file')),
              ),
              TextButton.icon(
                onPressed: () => controller.revealTaskFile(task),
                icon: const Icon(Icons.folder_open_outlined, size: 17),
                label: Text(trt('button_reveal_file')),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The checklist gets its own, more prominent card: it is the part of a
/// task the owner acts on.
class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.task, required this.controller});

  final HandoffTask task;
  final TasksController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = task.actions.length;
    final done = task.doneActionCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppLayout.radiusLarge),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trt('section_actions'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (total > 0)
                Text(
                  trt(
                    'text_progress',
                    namedArgs: {'done': '$done', 'total': '$total'},
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            ProgressBar(done: done, total: total),
            const SizedBox(height: 10),
            for (var i = 0; i < task.actions.length; i++)
              _ActionRow(
                action: task.actions[i],
                onChanged: (isDone) =>
                    controller.toggleAction(task, i, isDone: isDone),
                onAsk: task.workingDirectory == null
                    ? null
                    : () => controller.connectAgent(
                        task,
                        focus: task.actions[i].text,
                      ),
              ),
            if (task.areAllActionsDone && task.isOpen)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.celebration_outlined,
                      size: 16,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      trt('text_all_done_hint'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF16A34A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Text(
                trt('text_no_actions'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppLayout.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  const _ActionRow({required this.action, required this.onChanged, this.onAsk});

  final TaskAction action;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onAsk;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDone = widget.action.isDone;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(!isDone),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered
                ? scheme.onSurface.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Checkbox(
                  value: isDone,
                  onChanged: (value) => widget.onChanged(value ?? false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: isDone
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: scheme.onSurfaceVariant,
                    ),
                    child: MarkdownText(widget.action.text, inline: true),
                  ),
                ),
              ),
              if (widget.onAsk != null)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _isHovered ? 1 : 0,
                  child: IconButton(
                    tooltip: trt('button_ask_agent_item'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.forum_outlined, size: 16),
                    onPressed: widget.onAsk,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TagTone { neutral, success }

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.tone = _TagTone.neutral});

  final String label;
  final _TagTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSuccess = tone == _TagTone.success;
    final color = isSuccess ? const Color(0xFF16A34A) : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSuccess
            ? color.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
