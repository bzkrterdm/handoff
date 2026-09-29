import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../common/errors/api/api_error.dart';
import '../../common/exceptions/invalid_response_exception.dart';
import '../../common/exceptions/network_unavailable_exception.dart';
import '../../common/models/api/api_call.dart';
import '../../common/models/api/api_cancel_token.dart';
import '../../common/models/api/api_content_type.dart';
import '../../common/models/api/api_method.dart';
import '../../common/models/api/api_response_type.dart';
import '../../common/models/api/api_result.dart';
import '../../common/models/api/api_setup_params.dart';
import '../../common/utils/path_generator.dart';
import '../logging/logger.dart';
import 'api_traffic_recorder.dart';
import 'connectivity_manager.dart';

/// An advanced http client to manage api operations such as get, post etc.
abstract class ApiManager {
  /// Sets up ApiManager by [setupParams]. To be called in main before runApp.
  void setup(ApiSetupParams setupParams);

  /// Sets the authorization bearer token in request headers.
  /// Can be called multiple times to update the token.
  void setBearerAuthToken(String? token);

  /// Sets the id token in request headers.
  /// Can be called multiple times to update the token.
  void setIdToken(String? idToken);

  /// Makes a call to the given [api]. See the example below.
  ///
  /// Ideally, define your API as a static method.
  /// ```dart
  /// abstract class ExampleApi {
  ///   static ApiCall<ExampleModel> getExample() {
  ///     return ApiCall(
  ///       method: ApiMethod.get,
  ///       path: '/example',
  ///       responseMapper: (response) {
  ///         return ExampleModel.fromJson(response);
  ///       },
  ///     );
  ///   }
  /// }
  /// ```
  /// Then, you can call this method passing the defined API.
  /// ```dart
  /// final example = await apiManager.call(ExampleApi.getExample());
  /// if (example.isSuccessful) print(example.value.toString());
  /// ```
  ///
  /// Additionally, you can use [cancelToken] to cancel the call.
  Future<ApiResult<TOutput>> call<TOutput extends Object>(
    ApiCall<TOutput> api, {
    ApiCancelToken? cancelToken,
  });

  Stream<ApiResult<TOutput>> callStream<TOutput extends Object>(
    ApiCall<TOutput> api, {
    ApiCancelToken? cancelToken,
  });

  /// Called when an API error occurres for any call.
  Stream<ApiError> get onApiError;
}

/// ApiManager Implementation
class ApiManagerImpl implements ApiManager {
  ApiManagerImpl(
    this._logger,
    this._connectivityManager,
    this._trafficRecorder,
  );

  /// Fallback timeout used when [ApiSetupParams] does not specify one.
  /// Give the environment specific values through [ApiSetupParams] instead of
  /// changing this.
  static const _defaultTimeout = Duration(seconds: 30);
  static const _defaultUploadAndDownloadTimeout = Duration(seconds: 90);

  final Logger _logger;
  final ConnectivityManager _connectivityManager;
  final ApiTrafficRecorder _trafficRecorder;

  Dio? _client;
  late HttpClientAdapter _initialHttpClientAdapter;
  late StreamController<ApiError> _onApiErrorController;

  /// The configured client, or a clear error instead of a
  /// `LateInitializationError` when [setup] was never called.
  Dio get _dio {
    final client = _client;
    if (client == null) {
      throw StateError('Call ApiManager.setup before making a call.');
    }

    return client;
  }

  @override
  void setup(ApiSetupParams setupParams) {
    // Initialize dio client.
    _client = Dio(
      BaseOptions(
        baseUrl: setupParams.baseUrl,
        headers: setupParams.baseHeaders,
        queryParameters: setupParams.baseQueryParams,
        connectTimeout: setupParams.connectTimeout ?? _defaultTimeout,
        sendTimeout: setupParams.requestTimeout ?? _defaultTimeout,
        receiveTimeout: setupParams.responseTimeout ?? _defaultTimeout,
      ),
    );

    // Add retry interceptor with the given retry count and delays.
    if (setupParams.retryCount != null) {
      _addRetryInterceptor(setupParams.retryCount!, setupParams.retryDelays);
    }
    // Save the initial HttpClientAdapter for a backup.
    _initialHttpClientAdapter = _client!.httpClientAdapter;
    // Initialize onApiError stream controller.
    _onApiErrorController = StreamController.broadcast();
  }

  @override
  void setBearerAuthToken(String? token) {
    if (token != null) {
      _dio.options.headers['authorization'] = 'Bearer $token';
      _logger.info(
        'Bearer token set : ${_dio.options.headers['authorization']}',
      );
    } else {
      _dio.options.headers.remove('authorization');
    }
  }

  @override
  void setIdToken(String? idToken) {
    if (idToken != null) {
      _dio.options.headers['csidtoken'] = idToken;
    } else {
      _dio.options.headers.remove('csidtoken');
    }
  }

  @override
  Future<ApiResult<TOutput>> call<TOutput extends Object>(
    ApiCall<TOutput> api, {
    ApiCancelToken? cancelToken,
  }) async {
    // Save old base url to revert at the end.
    final oldBaseUrl = _dio.options.baseUrl;
    // Generate a uuid for logging purpose.
    final uuid = const Uuid().v4().toUpperCase();

    try {
      // Update dio client's properties as per needs.
      _updateClientByApiCallParams(api);
      // Log the api request.
      _logRequest(uuid, api, api.canLogContent);
      _trafficRecorder.recordRequest(
        uuid,
        api,
        baseUrl: _dio.options.baseUrl,
        baseHeaders: _dio.options.headers,
      );
      // Check network connectivity.
      await _checkInternetConnection();
      // Call the given api.
      final response = await _callApi(api, cancelToken);
      // Log the api response.
      _logResponse(uuid, response, api.canLogContent);
      _trafficRecorder.recordResponse(
        uuid,
        response,
        includeBody: api.canLogContent,
      );
      // Return with success if response mapper is not provided
      // and the response is successful.
      if (api.responseMapper == null && _isSuccessful(response)) {
        if (api.method == ApiMethod.download) {
          final dirPath = await PathGenerator.getDownloadSaveDirectory();

          return ApiResult.success(
            value:
                PathGenerator.createDownloadedFilePath(
                      fileName: api.downloadFileName,
                      dirPath: dirPath,
                      headers: response.headers,
                      increaseFileNameCount: false,
                    )
                    as TOutput,
          );
        } else if (api.responseType != ApiResponseType.json) {
          // A text or bytes response already *is* the output type, so it can
          // be handed over as it is. Gating this on the response type rather
          // than on TOutput matters: an ApiCall<String> against a json
          // endpoint with no mapper used to pass the decoded Map into a
          // String slot, and the resulting TypeError is an Error, not an
          // Exception — it escaped the catch below and crashed the caller.
          return ApiResult<TOutput>.success(value: response.data);
        }
        return ApiResult.success();
      }
      // Validate response data by the expected response type.
      _validateResponseData(response, api.responseType);
      // Return result after mapping with the given mapper.
      if (api.responseType == ApiResponseType.json) {
        return ApiResult.success(value: api.responseMapper!(response.data));
      }
      return ApiResult<TOutput>.success(value: response.data);
    } on Exception catch (ex) {
      final apiError = _getApiError(ex, cancelToken, uuid);
      return ApiResult.failure(apiError);
    } finally {
      // Revert the old base url in case it's changed.
      _dio.options.baseUrl = oldBaseUrl;
    }
  }

  /// Makes a streaming call to the given [api] for Server-Sent Events (SSE).
  /// Uses Dio's native stream support instead of eventsource package to avoid
  /// stack overflow issues with large base64 strings in release builds.
  @override
  Stream<ApiResult<TOutput>> callStream<TOutput extends Object>(
    ApiCall<TOutput> api, {
    ApiCancelToken? cancelToken,
  }) async* {
    // Generate a uuid for logging purpose.
    final uuid = const Uuid().v4().toUpperCase();
    Response<ResponseBody>? response;
    StreamSubscription<List<int>>? subscription;
    StreamController<ApiResult<TOutput>>? streamController;

    try {
      // Log the api request.
      _logRequest(uuid, api, api.canLogContent);
      // Check network connectivity.
      await _checkInternetConnection();

      // Build the complete URL
      var url = api.path;

      // Add query parameters to URL if provided
      if (api.queryParams != null && api.queryParams!.isNotEmpty) {
        final uri = Uri.parse(url);
        final filteredQueryParams = <String, String>{};
        filteredQueryParams.addAll(uri.queryParameters);
        api.queryParams!.forEach((key, value) {
          if (value != null) {
            filteredQueryParams[key] = value.toString();
          }
        });
        final newUri = uri.replace(queryParameters: filteredQueryParams);
        url = newUri.toString();
      }

      // Prepare headers for SSE
      final headers = <String, dynamic>{
        ..._dio.options.headers,
        if (api.headers != null) ...api.headers!,
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      };

      // Create Dio request with stream response.
      // SSE typically uses GET, but POST when a body is provided.
      // Disable smart-retry: retrying a chat stream duplicates the message
      // request and keeps the connection alive after the user stops/leaves.
      final httpMethod = api.body != null ? 'POST' : 'GET';
      final options = Options(
        method: httpMethod,
        headers: headers,
        responseType: ResponseType.stream,
      )..disableRetry = true;
      try {
        response = await _dio.request<ResponseBody>(
          url,
          data: api.body,
          options: options,
          cancelToken: cancelToken?.token,
        );
      } catch (e) {
        // Ignore connection errors when cancelled
        if (cancelToken?.token.isCancelled == true) {
          _logger.debug(
            '[$uuid] Ignoring SSE connection error (cancelled): $e',
            callerType: runtimeType,
            logRemote: false,
          );
          return;
        }
        rethrow;
      }

      _logger.debug(
        '[$uuid] SSE Connection established: $url',
        callerType: runtimeType,
        logRemote: false,
      );

      // Create a stream controller to manage the events
      streamController = StreamController<ApiResult<TOutput>>(
        onCancel: () {
          _logger.debug(
            '[$uuid] SSE Stream subscription cancelled by client',
            callerType: runtimeType,
            logRemote: false,
          );
          cancelToken?.cancel();
          subscription?.cancel();
          _logger.debug(
            '[$uuid] SSE Connection closed on server side',
            callerType: runtimeType,
            logRemote: false,
          );
        },
      );

      // SSE parsing state - using simple string operations instead of regex
      // to avoid stack overflow with large base64 strings
      final buffer = StringBuffer();
      String? currentEvent;
      final dataLines = <String>[];

      // Listen to the response stream
      subscription = response.data!.stream.listen(
        (List<int> chunk) {
          try {
            // Decode chunk and add to buffer
            final chunkStr = utf8.decode(chunk, allowMalformed: true);
            buffer.write(chunkStr);

            // Process complete lines from buffer
            final bufferContent = buffer.toString();
            final lastNewlineIndex = bufferContent.lastIndexOf('\n');

            if (lastNewlineIndex == -1) {
              // No complete line yet, keep buffering
              return;
            }

            // Extract complete lines and keep remainder in buffer
            final completeContent = bufferContent.substring(
              0,
              lastNewlineIndex + 1,
            );
            final remainder = bufferContent.substring(lastNewlineIndex + 1);
            buffer.clear();
            buffer.write(remainder);

            // Process each line without using regex to avoid stack overflow
            final lines = completeContent.split('\n');
            for (final line in lines) {
              if (line.isEmpty) {
                // Empty line means end of event - emit it
                if (dataLines.isNotEmpty) {
                  final eventType = currentEvent ?? 'message';
                  final eventData = dataLines.join('\n');

                  _processSSEEvent(
                    uuid: uuid,
                    eventType: eventType,
                    eventData: eventData,
                    api: api,
                    cancelToken: cancelToken,
                    streamController: streamController,
                  );
                }
                // Reset for next event
                currentEvent = null;
                dataLines.clear();
                continue;
              }

              // Parse SSE field without regex - find first colon
              final colonIndex = line.indexOf(':');
              if (colonIndex == 0) {
                // Comment line (starts with colon), ignore
                continue;
              }

              String field;
              String value;

              if (colonIndex == -1) {
                // No colon, entire line is field name with empty value
                field = line;
                value = '';
              } else {
                field = line.substring(0, colonIndex);
                // Value starts after colon, skip optional space
                var valueStart = colonIndex + 1;
                if (valueStart < line.length && line[valueStart] == ' ') {
                  valueStart++;
                }
                value = line.substring(valueStart);
              }

              // Handle SSE fields
              switch (field) {
                case 'event':
                  currentEvent = value;
                case 'data':
                  dataLines.add(value);
                case 'id':
                  // We don't use event ID, but could store it if needed
                  break;
                case 'retry':
                  // We don't handle retry, but could if needed
                  break;
              }
            }

            // Check if cancelled via cancelToken
            if (cancelToken?.token.isCancelled == true) {
              _logger.debug(
                '[$uuid] SSE Connection cancelled via cancelToken',
                callerType: runtimeType,
                logRemote: false,
              );
              subscription?.cancel();
              streamController?.close();
            }
          } catch (ex) {
            final apiError = _getApiError(ex as Exception, cancelToken, uuid);
            streamController?.add(ApiResult.failure(apiError));
          }
        },
        onError: (Object error) {
          final errorString = error.toString().toLowerCase();
          if (errorString.contains('connection closed') ||
              errorString.contains('socket') ||
              errorString.contains('http') ||
              errorString.contains('io') ||
              cancelToken?.token.isCancelled == true) {
            // Silently ignore these errors - they are expected when cancelling
            return;
          }

          // Only handle real errors
          final apiError = _getApiError(
            Exception('SSE stream error: $error'),
            cancelToken,
            uuid,
          );
          streamController?.add(ApiResult.failure(apiError));
        },
        onDone: () {
          // Process any remaining data in buffer
          if (dataLines.isNotEmpty) {
            final eventType = currentEvent ?? 'message';
            final eventData = dataLines.join('\n');
            _processSSEEvent(
              uuid: uuid,
              eventType: eventType,
              eventData: eventData,
              api: api,
              cancelToken: cancelToken,
              streamController: streamController,
            );
          }

          _logger.debug(
            '[$uuid] SSE Connection done',
            callerType: runtimeType,
            logRemote: false,
          );
          streamController?.close();
        },
      );

      // Yield all events from the stream controller
      await for (final result in streamController.stream) {
        yield result;
      }
    } on Exception catch (ex) {
      final apiError = _getApiError(ex, cancelToken, uuid);
      yield ApiResult.failure(apiError);
    } finally {
      // Ensure cleanup happens even if there's an exception
      await subscription?.cancel();
      await streamController?.close();
      _logger.debug(
        '[$uuid] SSE Stream cleanup completed',
        callerType: runtimeType,
        logRemote: false,
      );
    }
  }

  /// Processes a single SSE event and adds the result to the stream controller.
  void _processSSEEvent<TOutput extends Object>({
    required String uuid,
    required String eventType,
    required String eventData,
    required ApiCall<TOutput> api,
    required ApiCancelToken? cancelToken,
    required StreamController<ApiResult<TOutput>>? streamController,
  }) {
    try {
      if (eventType == 'error') {
        final apiError = _getApiError(
          Exception('SSE Error event received: $eventData'),
          cancelToken,
          uuid,
        );
        streamController?.add(ApiResult.failure(apiError));
        return;
      }

      final trimmedData = eventData.trim();
      if (trimmedData.isEmpty) {
        return;
      }

      if (api.canLogContent) {
        _logger.debug(
          '[$uuid] Event: $eventType | Data received: $trimmedData',
          callerType: runtimeType,
          logRemote: false,
        );
      }

      if (api.responseMapper != null) {
        try {
          final jsonData = jsonDecode(trimmedData);
          jsonData['event'] = eventType;
          final mappedData = api.responseMapper!(jsonData);
          streamController?.add(ApiResult.success(value: mappedData));
        } catch (jsonEx) {
          streamController?.add(
            ApiResult.success(value: trimmedData as TOutput),
          );
        }
      } else {
        streamController?.add(ApiResult.success(value: trimmedData as TOutput));
      }
    } catch (ex) {
      final apiError = _getApiError(ex as Exception, cancelToken, uuid);
      streamController?.add(ApiResult.failure(apiError));
    }
  }

  @override
  Stream<ApiError> get onApiError => _onApiErrorController.stream;

  // Helpers
  void _updateClientByApiCallParams(ApiCall<dynamic> api) {
    // Ignore base url to use endpoint only if specified by the api.
    if (api.ignoreBaseUrl == true) _dio.options.baseUrl = '';
    // Ignore bad certificate if specified.
    if (api.ignoreBadCertificate == true) {
      _ignoreBadCertificate();
    } else {
      // Revert ignore bad certificate.
      _dio.httpClientAdapter = _initialHttpClientAdapter;
    }
  }

  Future<void> _checkInternetConnection() async {
    // Throw an exception if internet connection is not available.
    if (!(await _connectivityManager.hasConnection)) {
      throw NetworkUnavailableException();
    }
  }

  Future<Response<dynamic>> _callApi<TOutput extends Object>(
    ApiCall<TOutput> api,
    ApiCancelToken? cancelToken,
  ) {
    return api.fileDecode
        ? _decodeFile(
            api.path,
            cancelToken,
            queryParameters: api.queryParams,
            fileName: api.downloadFileName,
          )
        : api.method == ApiMethod.download
        // Download file with a given optional file name.
        ? _download(
            api.path,
            cancelToken,
            queryParameters: api.queryParams,
            fileName: api.downloadFileName,
            body: api.body,
          )
        // Call the api with the generic request method.
        : _dio.request(
            api.path,
            data: api.body,
            options: Options(
              sendTimeout: api.isFileUpload
                  ? _defaultUploadAndDownloadTimeout
                  : null,
              // Parse http method from the method enum.
              method: api.method.name,
              // Combine request headers with base headers.
              headers: api.headers,
              // Set content type as per the configured content type.
              contentType: api.contentType == ApiContentType.json
                  ? 'application/json'
                  : 'charset=utf-8',
              // Set response type as per the configured response type.
              responseType: api.responseType == ApiResponseType.json
                  ? ResponseType.json
                  : api.responseType == ApiResponseType.bytes
                  ? ResponseType.bytes
                  : ResponseType.plain,
            ),
            queryParameters: api.queryParams,
            cancelToken: cancelToken?.token,
          );
  }

  Future<Response<dynamic>> _download(
    String url,
    ApiCancelToken? cancelToken, {
    Map<String, dynamic>? queryParameters,
    String? fileName,
    dynamic body,
  }) async {
    final isPermitted = await _checkPermission();
    if (!isPermitted) throw Exception('Permission not granted');

    final dirPath = await PathGenerator.getDownloadSaveDirectory();

    return _dio.download(
      url,
      (Headers headers) => PathGenerator.createDownloadedFilePath(
        fileName: fileName,
        dirPath: dirPath,
        headers: headers,
      ),
      cancelToken: cancelToken?.token,
      queryParameters: queryParameters,
      data: body,
      options: Options(
        method: body != null ? 'POST' : 'GET',
        contentType: 'application/json',
        responseType: ResponseType.bytes,
        receiveTimeout: _defaultUploadAndDownloadTimeout,
        headers: {HttpHeaders.acceptEncodingHeader: '*'},
      ),
    );
  }

  Future<Response<dynamic>> _decodeFile(
    String url,
    ApiCancelToken? cancelToken, {
    Map<String, dynamic>? queryParameters,
    String? fileName,
  }) async {
    final isPermitted = await _checkPermission();
    if (!isPermitted) throw Exception('Permission not granted');

    final dirPath = await PathGenerator.getDownloadSaveDirectory();
    final filePath = PathGenerator.createDownloadedFilePath(
      headers: Headers(),
      fileName: fileName,
      dirPath: dirPath,
    );

    final response = await _dio.request<dynamic>(
      url,
      options: Options(
        method: 'GET',
        contentType: 'application/json',
        responseType: ResponseType.json,
      ),
      queryParameters: queryParameters,
      cancelToken: cancelToken?.token,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to download the base64 encoded file.');
    }
    final String base64File = response.data['file'];
    final bytes = base64Decode(base64File);
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return Response(
      data: {'id': response.data['id'], 'filePath': filePath},
      statusCode: 200,
      requestOptions: RequestOptions(path: url),
    );
  }

  void _logRequest(String uuid, ApiCall<dynamic> request, bool canLogContent) {
    final method = request.method.name.toUpperCase();
    _logger.debug(
      '[$uuid] Request: $method ${request.path}',
      callerType: runtimeType,
      logRemote: false,
    );

    if (canLogContent &&
        (request.queryParams != null || request.body != null)) {
      // Log request params if provided.
      final encodedParams = jsonEncode(request.queryParams);
      if (request.queryParams != null && encodedParams.isNotEmpty) {
        _logger.debug(
          '[$uuid] RequestParams: $encodedParams',
          callerType: runtimeType,
          logRemote: false,
        );
      }
      // Log request body if provided.
      final encodedBody = request.body is Map
          ? jsonEncode(request.body)
          : request.body;
      if ((encodedBody is String || encodedBody is List) &&
          encodedBody.isNotEmpty) {
        _logger.debug(
          '[$uuid] RequestBody: $encodedBody',
          callerType: runtimeType,
          logRemote: false,
        );
      }
    }
  }

  void _logResponse(
    String uuid,
    Response<dynamic> response,
    bool canLogContent,
  ) {
    final isSuccessful = _isSuccessful(response);
    final responseText = '${response.statusCode} ${response.statusMessage}';
    isSuccessful
        ? _logger.debug(
            '[$uuid] Response: $responseText',
            callerType: runtimeType,
            logRemote: false,
          )
        : _logger.error(
            '[$uuid] Response: $responseText',
            callerType: runtimeType,
            logRemote: false,
          );

    if (canLogContent && response.data != null) {
      isSuccessful
          ? _logger.debug(
              '[$uuid] ResponseBody: ${response.toString()}',
              callerType: runtimeType,
              logRemote: false,
            )
          : _logger.error(
              '[$uuid] ResponseBody: ${response.toString()}',
              callerType: runtimeType,
              logRemote: false,
            );
    }
  }

  void _addRetryInterceptor(int retryCount, List<Duration>? retryDelays) {
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logPrint: (message) {
          _logger.error(message, callerType: runtimeType, logRemote: false);
        },
        retries: retryCount,
        retryDelays:
            retryDelays ??
            const [
              Duration(seconds: 1),
              Duration(seconds: 2),
              Duration(seconds: 3),
            ],
      ),
    );
  }

  void _ignoreBadCertificate() {
    _dio.httpClientAdapter = Http2Adapter(
      ConnectionManager(
        // Ignore bad certificate.
        onClientCreate: (_, config) => config.onBadCertificate = (_) => true,
      ),
    );
  }

  void _validateResponseData(
    Response<dynamic> response,
    ApiResponseType responseType,
  ) {
    // Throw an exception if response is not in valid format.
    if (responseType == ApiResponseType.text && response.data is! String) {
      throw InvalidResponseException();
    }
  }

  bool _isSuccessful(Response<dynamic> response) {
    if (response.statusCode == null) return false;
    return response.statusCode! >= 200 && response.statusCode! < 300;
  }

  Future<bool> _checkPermission() async {
    if (Platform.isIOS) return true;

    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt > 28) return true;

      final status = await Permission.storage.status;
      if (status == PermissionStatus.granted) return true;

      final result = await Permission.storage.request();
      return result == PermissionStatus.granted;
    }

    throw StateError('Unknown platform');
  }

  ApiError _getApiError(
    Exception ex,
    ApiCancelToken? cancelToken,
    String uuid,
  ) {
    // Refresh cancel token to be able to use again.
    cancelToken?.refresh();
    // Log error and return in ApiResult.
    final apiError = ApiError.fromException(ex);
    _logger.error(
      '[$uuid] Error: ${apiError.toString()}',
      callerType: runtimeType,
      logRemote: false,
    );
    _onApiErrorController.add(apiError);
    return apiError;
  }

  // - Helpers
}
