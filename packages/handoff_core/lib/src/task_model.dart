import 'package:json_annotation/json_annotation.dart';

part 'task_model.g.dart';

/// Storage shape of a task, shared by every data source.
///
/// The field names are the columns the Supabase table will have (see
/// `docs/data-model.md`), which is why they are snake_case JSON
/// keys rather than the markdown headings the file store uses. The markdown
/// source builds this from a parsed file; the remote source will build it from
/// a row. Each app maps it to its own entity.
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
}

@JsonSerializable(fieldRename: FieldRename.snake)
class TaskActionModel {
  const TaskActionModel({required this.text, this.isDone = false});

  final String text;
  final bool isDone;

  factory TaskActionModel.fromJson(Map<String, dynamic> json) =>
      _$TaskActionModelFromJson(json);

  Map<String, dynamic> toJson() => _$TaskActionModelToJson(this);
}
