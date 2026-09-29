import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/handoff_task.dart';
import '../../domain/entities/task_action.dart';
import '../../domain/entities/task_status.dart';

part 'task_model.g.dart';

/// Storage shape of a task, shared by every data source.
///
/// The field names are the columns the Supabase table will have (see
/// `ai_docs/backend/data-model.md`), which is why they are snake_case JSON
/// keys rather than the markdown headings the file store uses. The markdown
/// source builds this from a parsed file; the remote source will build it from
/// a row. Both hand the entity up through [toEntity].
@JsonSerializable(fieldRename: FieldRename.snake)
class TaskModel {
  const TaskModel({
    required this.id,
    required this.project,
    required this.title,
    required this.agent,
    required this.createdAt,
    required this.status,
    this.closedAt,
    this.related = const [],
    this.summary = '',
    this.info = '',
    this.actions = const [],
    this.location,
    this.cwd,
    this.sessionId,
  });

  final String id;
  final String project;
  final String title;
  final String agent;
  final DateTime createdAt;
  final DateTime? closedAt;
  final String status;
  final List<String> related;
  final String summary;
  final String info;
  final List<TaskActionModel> actions;

  /// Not persisted remotely: the file path for the markdown store.
  @JsonKey(includeToJson: false)
  final String? location;

  /// Agent working directory relative to the workspace root (front matter
  /// `cwd`).
  final String? cwd;

  /// The agent's session id (front matter `session`), for resuming.
  final String? sessionId;

  factory TaskModel.fromJson(Map<String, dynamic> json) =>
      _$TaskModelFromJson(json);

  Map<String, dynamic> toJson() => _$TaskModelToJson(this);

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

@JsonSerializable(fieldRename: FieldRename.snake)
class TaskActionModel {
  const TaskActionModel({required this.text, this.isDone = false});

  final String text;
  final bool isDone;

  factory TaskActionModel.fromJson(Map<String, dynamic> json) =>
      _$TaskActionModelFromJson(json);

  Map<String, dynamic> toJson() => _$TaskActionModelToJson(this);

  TaskAction toEntity() => TaskAction(text: text, isDone: isDone);
}
