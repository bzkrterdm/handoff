import 'package:equatable/equatable.dart';

import '../../../../stack/common/models/failure.dart';
import 'handoff_task.dart';

/// One read of the store: where it is and what it holds. When the store
/// could not be read, [error] says why and [tasks] is empty — the location
/// is still reported so the owner can see (and change) which folder failed.
class TaskSnapshot extends Equatable {
  const TaskSnapshot({
    required this.workspace,
    this.tasks = const [],
    this.error,
  });

  final String workspace;
  final List<HandoffTask> tasks;
  final Failure? error;

  @override
  List<Object?> get props => [workspace, tasks, error];
}
