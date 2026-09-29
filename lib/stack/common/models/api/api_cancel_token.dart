import 'package:dio/dio.dart';

class ApiCancelToken {
  CancelToken _token = CancelToken();

  /// Internal token. Obscured because it's only used in ApiManager.
  dynamic get token => _token;

  /// Cancel apis which this token is provided to.
  void cancel() => _token.cancel();

  /// Refresh the current cancel token.
  /// Should be used when cancellation is completed.
  void refresh() => _token = CancelToken();
}
