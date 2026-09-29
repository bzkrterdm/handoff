import '../../../../stack/base/domain/use_case.dart';
import '../../../../stack/common/models/failure.dart';
import '../../../../stack/common/models/result.dart';
import '../repositories/task_repository.dart';

/// Points the app at another task folder.
class SetWorkspace extends UseCase<String, String, void> {
  SetWorkspace(super.logger, this._repository);

  final TaskRepository _repository;

  @override
  Future<Result<String, Failure>> execute({String? params}) {
    if (params == null || params.isEmpty) {
      return Future.value(
        Result.failure(const Failure(message: 'Missing workspace path.')),
      );
    }

    return _repository.setWorkspace(params);
  }
}
