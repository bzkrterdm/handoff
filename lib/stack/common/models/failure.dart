import 'package:equatable/equatable.dart';

import '../errors/api/api_error_type.dart';

class Failure extends Equatable {
  const Failure({required this.message, this.apiErrorType});

  /// Message to describe the failure.
  final String message;

  /// If the failure is related to an API call,
  /// this field will contain the type of the error.
  final ApiErrorType? apiErrorType;

  @override
  List<Object?> get props => [message, apiErrorType];
}
