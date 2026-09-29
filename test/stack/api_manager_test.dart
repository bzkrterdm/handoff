import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/stack/common/errors/api/api_error.dart';
import 'package:handoff/stack/common/errors/api/api_error_type.dart';
import 'package:handoff/stack/common/models/api/api_call.dart';
import 'package:handoff/stack/common/models/api/api_cancel_token.dart';
import 'package:handoff/stack/common/models/api/api_method.dart';
import 'package:handoff/stack/common/models/api/api_response_type.dart';
import 'package:handoff/stack/common/models/api/api_setup_params.dart';
import 'package:handoff/stack/common/models/result.dart';
import 'package:handoff/stack/core/logging/logger.dart';
import 'package:handoff/stack/core/network/api_manager.dart';
import 'package:handoff/stack/core/network/api_traffic_recorder.dart';
import 'package:handoff/stack/core/network/connectivity_manager.dart';

/// Drives `ApiManagerImpl` against a real loopback server rather than a mocked
/// adapter: the dio client it builds is private, and the interesting parts
/// (status mapping, headers, cancellation, SSE parsing) only show up over an
/// actual socket.
void main() {
  late HttpServer server;
  late List<_ReceivedRequest> received;
  late _FakeConnectivityManager connectivity;
  late ApiTrafficRecorder recorder;
  late ApiManager apiManager;
  late Future<void> Function(HttpRequest request) respond;

  Future<void> respondJson(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'name': 'Ada'}));
    await request.response.close();
  }

  setUp(() async {
    received = [];
    respond = respondJson;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      received.add(
        _ReceivedRequest(
          method: request.method,
          path: request.uri.path,
          query: request.uri.queryParameters,
          authorization: request.headers.value('authorization'),
          idToken: request.headers.value('csidtoken'),
          body: await utf8.decoder.bind(request).join(),
        ),
      );
      await respond(request);
    });

    connectivity = _FakeConnectivityManager();
    recorder = ApiTrafficRecorder(enabled: true);
    apiManager = ApiManagerImpl(LoggerImpl(), connectivity, recorder)
      ..setup(
        ApiSetupParams(
          baseUrl: 'http://${server.address.host}:${server.port}/',
          baseHeaders: const {'accept': 'application/json'},
        ),
      );
  });

  tearDown(() async {
    await server.close(force: true);
  });

  group('ApiManager.call', () {
    test('maps a json response through the mapper', () async {
      final result = await apiManager.call(_nameCall());

      expect(result, isA<Success<String, ApiError>>());
      expect(result.value, 'Ada');
      expect(received.single.method, 'GET');
      expect(received.single.path, '/users');
    });

    test('sends query parameters and a body', () async {
      final result = await apiManager.call(
        ApiCall<String>(
          method: ApiMethod.post,
          path: 'users',
          queryParams: const {'page': 1},
          body: const {'name': 'Grace'},
          responseMapper: (response) => response['name'] as String,
        ),
      );

      expect(result.isSuccessful, isTrue);
      expect(received.single.method, 'POST');
      expect(received.single.query, {'page': '1'});
      expect(jsonDecode(received.single.body), {'name': 'Grace'});
    });

    test('succeeds without a value when no mapper is given', () async {
      // The declared output is String, the endpoint answers json and there is
      // no mapper: there is nothing to build a value from, so the call
      // succeeds empty instead of crashing on a bad cast.
      final result = await apiManager.call(
        ApiCall<String>(method: ApiMethod.post, path: 'ping'),
      );

      expect(result.isSuccessful, isTrue);
      expect(result.value, isNull);
    });

    test('returns the response as text when text is expected', () async {
      respond = (request) async {
        request.response.write('pong');
        await request.response.close();
      };

      final result = await apiManager.call(
        ApiCall<String>(
          method: ApiMethod.get,
          path: 'ping',
          responseType: ApiResponseType.text,
        ),
      );

      expect(result.value, 'pong');
    });

    test('maps a status code to its error type', () async {
      respond = (request) async {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
      };

      final result = await apiManager.call(_nameCall());

      expect(result, isA<Failed<String, ApiError>>());
      expect(result.error?.apiErrorType, ApiErrorType.unauthorized);
    });

    test('keeps the error response body for the caller', () async {
      respond = (request) async {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'code': 'INVALID'}));
        await request.response.close();
      };

      final result = await apiManager.call(_nameCall());

      expect(result.error?.apiErrorType, ApiErrorType.badRequest);
      expect(result.error?.response, {'code': 'INVALID'});
    });

    test('fails without calling out when there is no connection', () async {
      connectivity.hasConnectionValue = false;

      final result = await apiManager.call(_nameCall());

      expect(result.error?.apiErrorType, ApiErrorType.networkUnavailable);
      expect(received, isEmpty);
    });

    test('reports a cancelled call as cancelled', () async {
      respond = (request) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        await request.response.close();
      };
      final cancelToken = ApiCancelToken();
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 100),
          cancelToken.cancel,
        ),
      );

      final result = await apiManager.call(
        _nameCall(),
        cancelToken: cancelToken,
      );

      expect(result.error?.apiErrorType, ApiErrorType.operationCanceled);
    });

    test('publishes failures on the error stream', () async {
      respond = (request) async {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      };
      // The stream is broadcast, so the expectation has to be in place
      // before the call: a listener added after it would miss the event.
      final expectation = expectLater(
        apiManager.onApiError,
        emits(
          predicate<ApiError>(
            (error) => error.apiErrorType == ApiErrorType.notFound,
          ),
        ),
      );

      await apiManager.call(_nameCall());

      await expectation;
    });
  });

  group('ApiManager headers', () {
    test('sets and clears the bearer token', () async {
      apiManager.setBearerAuthToken('abc123');
      await apiManager.call(_nameCall());

      expect(received.single.authorization, 'Bearer abc123');

      apiManager.setBearerAuthToken(null);
      await apiManager.call(_nameCall());

      expect(received.last.authorization, isNull);
    });

    test('sets and clears the id token', () async {
      apiManager.setIdToken('id-1');
      await apiManager.call(_nameCall());

      expect(received.single.idToken, 'id-1');

      apiManager.setIdToken(null);
      await apiManager.call(_nameCall());

      expect(received.last.idToken, isNull);
    });
  });

  group('ApiManager.callStream', () {
    test('yields the events of a server sent event stream', () async {
      respond = (request) async {
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          'text/event-stream',
        );
        for (final word in ['first', 'second']) {
          request.response.write(
            'event: message\ndata: ${jsonEncode({'text': word})}\n\n',
          );
          await request.response.flush();
        }
        await request.response.close();
      };

      final values = await apiManager
          .callStream(
            ApiCall<String>(
              method: ApiMethod.get,
              path: 'stream',
              responseMapper: (response) => response['text'] as String,
            ),
          )
          .map((result) => result.value)
          .toList();

      expect(values, ['first', 'second']);
    });
  });

  group('ApiTrafficRecorder', () {
    test('records the request and its response', () async {
      await apiManager.call(_nameCall());

      final entry = recorder.entries.single;
      expect(entry.method, 'GET');
      expect(entry.url, contains('/users'));
      expect(entry.statusCode, HttpStatus.ok);
      expect(entry.responseBody, contains('Ada'));
      expect(entry.durationMs, isNotNull);
    });

    test('records nothing when it is disabled', () async {
      final disabled = ApiTrafficRecorder(enabled: false);
      final manager = ApiManagerImpl(LoggerImpl(), connectivity, disabled)
        ..setup(
          ApiSetupParams(
            baseUrl: 'http://${server.address.host}:${server.port}/',
          ),
        );

      await manager.call(_nameCall());

      expect(disabled.entries, isEmpty);
    });
  });
}

ApiCall<String> _nameCall() {
  return ApiCall<String>(
    method: ApiMethod.get,
    path: 'users',
    responseMapper: (response) => response['name'] as String,
  );
}

class _ReceivedRequest {
  _ReceivedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.authorization,
    required this.idToken,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final String? authorization;
  final String? idToken;
  final String body;
}

class _FakeConnectivityManager implements ConnectivityManager {
  bool hasConnectionValue = true;

  @override
  Future<bool> get hasConnection async => hasConnectionValue;

  @override
  Stream<ConnectionResult> get onConnectionChanged =>
      const Stream<ConnectionResult>.empty();
}
