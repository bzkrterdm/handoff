import 'package:equatable/equatable.dart';

class ApiTrafficEntry extends Equatable {
  const ApiTrafficEntry({
    required this.id,
    required this.method,
    required this.url,
    required this.startedAt,
    this.queryParameters,
    this.requestHeaders,
    this.requestBody,
    this.statusCode,
    this.statusMessage,
    this.responseHeaders,
    this.responseBody,
    this.error,
    this.finishedAt,
    this.durationMs,
  });

  final String id;
  final String method;
  final String url;
  final DateTime startedAt;
  final Map<String, String>? queryParameters;
  final Map<String, String>? requestHeaders;
  final String? requestBody;
  final int? statusCode;
  final String? statusMessage;
  final Map<String, String>? responseHeaders;
  final String? responseBody;
  final String? error;
  final DateTime? finishedAt;
  final int? durationMs;

  bool get isSuccess =>
      statusCode != null &&
      statusCode! >= 200 &&
      statusCode! < 300 &&
      error == null;

  bool get isCompleted => finishedAt != null || error != null;

  ApiTrafficEntry copyWith({
    String? id,
    String? method,
    String? url,
    DateTime? startedAt,
    Map<String, String>? queryParameters,
    Map<String, String>? requestHeaders,
    String? requestBody,
    int? statusCode,
    String? statusMessage,
    Map<String, String>? responseHeaders,
    String? responseBody,
    String? error,
    DateTime? finishedAt,
    int? durationMs,
  }) {
    return ApiTrafficEntry(
      id: id ?? this.id,
      method: method ?? this.method,
      url: url ?? this.url,
      startedAt: startedAt ?? this.startedAt,
      queryParameters: queryParameters ?? this.queryParameters,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      requestBody: requestBody ?? this.requestBody,
      statusCode: statusCode ?? this.statusCode,
      statusMessage: statusMessage ?? this.statusMessage,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
      error: error ?? this.error,
      finishedAt: finishedAt ?? this.finishedAt,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  @override
  List<Object?> get props => [
    id,
    method,
    url,
    startedAt,
    queryParameters,
    requestHeaders,
    requestBody,
    statusCode,
    statusMessage,
    responseHeaders,
    responseBody,
    error,
    finishedAt,
    durationMs,
  ];
}
