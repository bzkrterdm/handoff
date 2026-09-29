class ApiSetupParams {
  ApiSetupParams({
    required this.baseUrl,
    this.baseHeaders,
    this.baseQueryParams,
    this.connectTimeout,
    this.requestTimeout,
    this.responseTimeout,
    this.retryCount,
    this.retryDelays,
  });

  /// Base request url.
  /// It can contain sub paths like: "https://www.google.com/api/".
  final String baseUrl;

  /// Base headers to define for all the calls.
  final Map<String, dynamic>? baseHeaders;

  /// Base query parameters.
  final Map<String, dynamic>? baseQueryParams;

  /// Timeout for opening url.
  final Duration? connectTimeout;

  /// Timeout for sending data.
  final Duration? requestTimeout;

  /// Timeout for receiving data.
  final Duration? responseTimeout;

  /// The number of retries in case of an error.
  final int? retryCount;

  /// The delays between retries. Empty [retryDelays] means no delay.
  ///
  /// If [retryCount] is bigger than [retryDelays] count,
  /// the last element value of [retryDelays] will be used.
  final List<Duration>? retryDelays;
}
