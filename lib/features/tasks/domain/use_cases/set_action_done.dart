import 'package:equatable/equatable.dart';

import '../../../../stack/base/domain/use_case.dart';
import '../../../../stack/common/models/failure.dart';
import '../../../../stack/common/models/result.dart';
import '../entities/handoff_task.dart';
import '../repositories/task_repository.dart';

/// Ticks or unticks one expected item of a task.
class SetActionDone extends UseCase<SetActionDoneParams, HandoffTask, void> {
  SetActionDone(super.logger, this._repository);

  final TaskRepository _repository;

  @override
  Future<Result<HandoffTask, Failure>> execute({SetActionDoneParams? params}) {
    if (params == null) {
      return Future.value(
        Result.failure(const Failure(message: 'Missing params.')),
      );
    }

    return _repository.setActionDone(
      taskId: params.taskId,
      index: params.index,
      isDone: params.isDone,
    );
  }
}

class SetActionDoneParams extends Equatable {
  const SetActionDoneParams({
    required this.taskId,
    required this.index,
    required this.isDone,
  });

  final String taskId;
  final int index;
  final bool isDone;

  @override
  List<Object?> get props => [taskId, index, isDone];
}
