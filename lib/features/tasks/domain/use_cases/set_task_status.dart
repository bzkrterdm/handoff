import 'package:equatable/equatable.dart';

import '../../../../stack/base/domain/use_case.dart';
import '../../../../stack/common/models/failure.dart';
import '../../../../stack/common/models/result.dart';
import '../entities/handoff_task.dart';
import '../entities/task_status.dart';
import '../repositories/task_repository.dart';

/// Closes or reopens a task.
class SetTaskStatus extends UseCase<SetTaskStatusParams, HandoffTask, void> {
  SetTaskStatus(super.logger, this._repository);

  final TaskRepository _repository;

  @override
  Future<Result<HandoffTask, Failure>> execute({SetTaskStatusParams? params}) {
    if (params == null) {
      return Future.value(
        Result.failure(const Failure(message: 'Missing params.')),
      );
    }

    return _repository.setStatus(taskId: params.taskId, status: params.status);
  }
}

class SetTaskStatusParams extends Equatable {
  const SetTaskStatusParams({required this.taskId, required this.status});

  final String taskId;
  final TaskStatus status;

  @override
  List<Object?> get props => [taskId, status];
}
