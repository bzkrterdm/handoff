import 'package:equatable/equatable.dart';

import 'task_action.dart';
import 'task_status.dart';

/// A note an agent leaves for the owner when it finishes a piece of work:
/// what was done, what the owner should know, and what is expected of them.
///
/// Named `HandoffTask` rather than `Task` because the stack already has a
/// presentation `Task` (a reusable UI step).
class HandoffTask extends Equatable {
  const HandoffTask({
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
    this.workingDirectory,
    this.sessionId,
  });

  /// Stable identifier, unique across projects. In the file store it is the
  /// file name without extension.
  final String id;

  /// Workspace folder the work happened in, e.g. `acme/web` or
  /// `acme/api`. Tasks are grouped by this.
  final String project;

  final String title;

  /// Which agent wrote the task, e.g. `claude`, `codex`.
  final String agent;

  final DateTime createdAt;
  final DateTime? closedAt;
  final TaskStatus status;

  /// Ids of earlier tasks this one follows up on.
  final List<String> related;

  /// "Yapılan" — what the agent did, as markdown.
  final String summary;

  /// "Bilgi" — details the owner asked for or should know, as markdown.
  final String info;

  /// "Senden beklenenler" — the owner's checklist.
  final List<TaskAction> actions;

  /// Where the task lives in the current store: a file path today, a row
  /// reference once the store is remote. Null when the store has no notion of
  /// a location the owner can open.
  final String? location;

  /// Folder the agent should be started in, relative to the workspace root.
  /// Defaults to [project] when the task does not say.
  final String? workingDirectory;

  /// The agent's own session id, when it knew it. Lets "connect" resume the
  /// original conversation instead of starting a fresh one.
  final String? sessionId;

  bool get isOpen => status == TaskStatus.open;

  bool get isDone => status == TaskStatus.done;

  int get doneActionCount => actions.where((action) => action.isDone).length;

  /// Whether every expected item is ticked. False when there is nothing to
  /// tick, so that an informational task still needs an explicit close.
  bool get areAllActionsDone =>
      actions.isNotEmpty && doneActionCount == actions.length;

  HandoffTask copyWith({
    TaskStatus? status,
    DateTime? closedAt,
    List<TaskAction>? actions,
  }) {
    return HandoffTask(
      id: id,
      project: project,
      title: title,
      agent: agent,
      createdAt: createdAt,
      status: status ?? this.status,
      closedAt: closedAt ?? this.closedAt,
      related: related,
      summary: summary,
      info: info,
      actions: actions ?? this.actions,
      location: location,
      workingDirectory: workingDirectory,
      sessionId: sessionId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    project,
    title,
    agent,
    createdAt,
    closedAt,
    status,
    related,
    summary,
    info,
    actions,
    location,
    workingDirectory,
    sessionId,
  ];
}
