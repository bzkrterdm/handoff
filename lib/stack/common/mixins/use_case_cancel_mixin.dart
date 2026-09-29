import '../../base/domain/use_case.dart';

mixin UseCaseCancelMixin {
  List<UseCase<dynamic, dynamic, dynamic>> get useCasesToCancel;

  void cancelUseCases() {
    for (final useCase in useCasesToCancel) {
      useCase.stop();
    }
  }
}
