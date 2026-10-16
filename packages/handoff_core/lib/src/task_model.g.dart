// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskModel _$TaskModelFromJson(Map<String, dynamic> json) => TaskModel(
  id: json['id'] as String,
  project: json['project'] as String,
  title: json['title'] as String,
  agent: json['agent'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  status: json['status'] as String,
  closedAt: json['closed_at'] == null
      ? null
      : DateTime.parse(json['closed_at'] as String),
  related:
      (json['related'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  summary: json['summary'] as String? ?? '',
  info: json['info'] as String? ?? '',
  actions:
      (json['actions'] as List<dynamic>?)
          ?.map((e) => TaskActionModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  location: json['location'] as String?,
  cwd: json['cwd'] as String?,
  sessionId: json['session_id'] as String?,
);

Map<String, dynamic> _$TaskModelToJson(TaskModel instance) => <String, dynamic>{
  'id': instance.id,
  'project': instance.project,
  'title': instance.title,
  'agent': instance.agent,
  'created_at': instance.createdAt.toIso8601String(),
  'closed_at': instance.closedAt?.toIso8601String(),
  'status': instance.status,
  'related': instance.related,
  'summary': instance.summary,
  'info': instance.info,
  'actions': instance.actions,
  'cwd': instance.cwd,
  'session_id': instance.sessionId,
};

TaskActionModel _$TaskActionModelFromJson(Map<String, dynamic> json) =>
    TaskActionModel(
      text: json['text'] as String,
      isDone: json['is_done'] as bool? ?? false,
    );

Map<String, dynamic> _$TaskActionModelToJson(TaskActionModel instance) =>
    <String, dynamic>{'text': instance.text, 'is_done': instance.isDone};
