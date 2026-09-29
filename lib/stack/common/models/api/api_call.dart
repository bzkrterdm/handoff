import 'dart:typed_data';

import 'api_content_type.dart';
import 'api_method.dart';
import 'api_response_type.dart';

class ApiCall<TOutput extends Object> {
  ApiCall({
    required this.method,
    required this.path,
    this.headers,
    this.contentType = ApiContentType.json,
    this.responseType = ApiResponseType.json,
    this.responseMapper,
    this.queryParams,
    this.body,
    this.downloadFileName,
    this.ignoreBaseUrl,
    this.ignoreBadCertificate,
    this.canLogContent = true,
    this.isFileUpload = false,
    this.fileDecode = false,
  }) {
    _assertGetMethod();
    _assertDownloadMethod();
    _assertResponses();
  }

  /// Api method.
  final ApiMethod method;

  /// Api path. It can also be an endpoint if base url is provided.
  final String path;

  /// Request headers to be combined with base headers.
  final Map<String, dynamic>? headers;

  /// Specified api request content type. Defaults to [ApiContentType.json].
  final ApiContentType contentType;

  /// Expected api response type. Defaults to [ApiResponseType.json].
  final ApiResponseType responseType;

  /// Mapper to deserialize response JSON map.
  final TOutput Function(dynamic response)? responseMapper;

  /// Additional query parameters.
  final Map<String, dynamic>? queryParams;

  /// Request body to send.
  final dynamic body;

  /// Optional name of the file to be downloaded.
  final String? downloadFileName;

  /// Ignore base url to be able to use full path only.
  final bool? ignoreBaseUrl;

  /// Whether ignore bad certificate or not.
  final bool? ignoreBadCertificate;

  /// Whether request/response contents can be logged or not. Defaults to true.
  final bool canLogContent;

  /// Whether requests is for upload or not. Defaults to false.
  final bool isFileUpload;

  /// Whether requests is for file decode from base64 or not. Defaults to false.
  final bool fileDecode;

  // Helpers
  void _assertGetMethod() {
    if (method == ApiMethod.get) {
      assert(body == null, 'Get APIs cannot have a body to send!');
    }
  }

  void _assertDownloadMethod() {
    if (method == ApiMethod.download) {
      assert(
        responseMapper == null,
        'Download APIs cannot have a response mapper!',
      );
    }
  }

  void _assertResponses() {
    if (responseType == ApiResponseType.json && method == ApiMethod.get) {
      _assertJsonResponse();
    } else if (responseType == ApiResponseType.text) {
      _assertTextResponse();
    } else if (responseType == ApiResponseType.bytes) {
      _assertBytesResponse();
    }
  }

  void _assertJsonResponse() {
    assert(
      responseMapper != null,
      '''
Get APIs must have a response mapper provided if JSON is expected as a response!''',
    );
  }

  void _assertTextResponse() {
    assert(
      TOutput == String,
      'Output type should be String if text is expected as a response!',
    );
    assert(
      responseMapper == null,
      'Response mapper cannot be set if text is expected as a response!',
    );
  }

  void _assertBytesResponse() {
    assert(
      TOutput == Uint8List,
      'Output type should be Uint8List if bytes is expected as a response!',
    );
    assert(
      responseMapper == null,
      'Response mapper cannot be set if bytes is expected as a response!',
    );
  }

  // - Helpers
}
