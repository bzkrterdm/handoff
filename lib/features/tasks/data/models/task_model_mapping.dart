import 'package:handoff_core/handoff_core.dart';

import '../../domain/entities/handoff_task.dart';
import '../../domain/entities/task_action.dart';
import '../../domain/entities/task_status.dart';

export 'package:handoff_core/handoff_core.dart' show TaskActionModel, TaskModel;

/// The storage shape ([TaskModel], shared with the terminal app through
/// `handoff_core`) mapped to this app's domain entity.
extension TaskModelMapping on TaskModel {
  HandoffTask toEntity() {
    return HandoffTask(
      id: id,
      project: project,
      title: title,
      agent: agent,
      createdAt: createdAt,
      closedAt: closedAt,
      status: TaskStatus.parse(status),
      related: related,
      summary: summary,
      info: info,
      actions: actions.map((action) => action.toEntity()).toList(),
      location: location,
      workingDirectory: cwd,
      sessionId: sessionId,
    );
  }
}

extension TaskActionModelMapping on TaskActionModel {
  TaskAction toEntity() => TaskAction(text: text, isDone: isDone);
}
