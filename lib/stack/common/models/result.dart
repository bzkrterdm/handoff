import 'package:equatable/equatable.dart';

import 'failure.dart';

/// A union type to be used anywhere an operation can fail. [TValue] and
/// [TError] can be provided as desired, then the result is created through the
/// [Result.success] or [Result.failure] factory constructors.
///
/// ```dart
/// Result<Foo, Failure> foo() {
///   return Result.success(value: Foo());
///   or
///   return Result.failure(Failure(message: 'Error occurred!'));
/// }
/// ```
///
/// Being sealed, a result can be handled exhaustively — the compiler rejects
/// the switch if a case is missing, and neither branch needs a null check:
///
/// ```dart
/// switch (foo()) {
///   case Success(:final value):
///     print(value);
///   case Failed(:final error):
///     print(error.message);
/// }
/// ```
///
/// [isSuccessful], [value] and [error] are there for the cases a switch would
/// be noise, and for code that only asks whether the call worked:
///
/// ```dart
/// final result = foo();
/// if (!result.isSuccessful) return;
/// ```
///
/// Generic type parameters can be omitted for an operation that has nothing to
/// return. [isSuccessful] is then the whole result:
///
/// ```dart
/// Result bar() => Result.success();
/// ```
sealed class Result<TValue extends Object, TError extends Failure>
    extends Equatable {
  const Result();

  /// Indicates if the result is successful or not.
  bool get isSuccessful;

  /// Value object, set on a successful result that carries one.
  /// Prefer matching on [Success] over null checking this.
  TValue? get value;

  /// Error object, set exactly when the result is a failure.
  /// Prefer matching on [Failed] over null checking this.
  TError? get error;

  /// A successful result, carrying [value] when there is one to carry.
  const factory Result.success({TValue? value}) = Success<TValue, TError>;

  /// A failed result, carrying [error]. Unlike the value of a success, the
  /// error of a failure is never null.
  const factory Result.failure(TError error) = Failed<TValue, TError>;
}

/// The successful branch of a [Result].
final class Success<TValue extends Object, TError extends Failure>
    extends Result<TValue, TError> {
  const Success({this.value});

  @override
  final TValue? value;

  @override
  bool get isSuccessful => true;

  @override
  TError? get error => null;

  @override
  List<Object?> get props => [value];
}

/// The failed branch of a [Result].
final class Failed<TValue extends Object, TError extends Failure>
    extends Result<TValue, TError> {
  const Failed(this.error);

  @override
  final TError error;

  @override
  bool get isSuccessful => false;

  @override
  TValue? get value => null;

  @override
  List<Object?> get props => [error];
}
