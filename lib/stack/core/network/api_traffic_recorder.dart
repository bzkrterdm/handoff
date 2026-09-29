import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../common/models/api/api_call.dart';
import '../../common/models/api/api_method.dart';
import '../../common/models/api/api_traffic_entry.dart';

class ApiTrafficRecorder {
  /// Records nothing unless [enabled]. Defaults to debug builds only, so
  /// that release builds never keep request/response bodies in memory.
  /// Pass the flag explicitly to record in a non-production environment.
  ApiTrafficRecorder({bool? enabled}) : _enabled = enabled ?? kDebugMode;

  final bool _enabled;
  final _entries = <String, ApiTrafficEntry>{};
  final _listeners = <void Function(List<ApiTrafficEntry>)>[];

  List<ApiTrafficEntry> get entries => _sortedEntries;

  void addListener(void Function(List<ApiTrafficEntry>) listener) {
    _listeners.add(listener);
    listener(_sortedEntries);
  }

  void removeListener(void Function(List<ApiTrafficEntry>) listener) {
    _listeners.remove(listener);
  }

  void clear() {
    if (!_enabled) return;
    _entries.clear();
    _notify();
  }

  void recordRequest(
    String id,
    ApiCall<dynamic> api, {
    required String baseUrl,
    required Map<String, dynamic>? baseHeaders,
  }) {
    if (!_enabled) return;
    _entries[id] = ApiTrafficEntry(
      id: id,
      method: api.method.name.toUpperCase(),
      url: _buildUrl(baseUrl, api.path, api.queryParams),
      startedAt: DateTime.now(),
      queryParameters: _stringifyMap(api.queryParams),
      requestHeaders: _stringifyMap({...?baseHeaders, ...?api.headers}),
      requestBody: api.canLogContent ? _stringify(api.body) : null,
    );
    _notify();
  }

  void recordResponse(
    String id,
    dynamic response, {
    required bool includeBody,
  }) {
    if (!_enabled) return;
    final now = DateTime.now();
    final previous = _entries[id];
    final body = includeBody ? _stringify(response.data) : null;
    // Use full URI from response if available, otherwise fallback to path
    final responseUrl = response.requestOptions.uri.toString();
    final updated =
        (previous ??
                ApiTrafficEntry(
                  id: id,
                  method: ApiMethod.get.name.toUpperCase(),
                  url: responseUrl,
                  startedAt: now,
                ))
            .copyWith(
              statusCode: response.statusCode,
              statusMessage: response.statusMessage,
              responseHeaders: _stringifyMap(response.headers.map),
              responseBody: body,
              finishedAt: now,
              durationMs: _computeDurationMs(previous?.startedAt, now),
            );
    _entries[id] = updated;
    _notify();
  }

  void recordError(String id, {String? message}) {
    if (!_enabled) return;
    final now = DateTime.now();
    final previous = _entries[id];
    final updated =
        (previous ??
                ApiTrafficEntry(
                  id: id,
                  method: ApiMethod.get.name.toUpperCase(),
                  url: '',
                  startedAt: now,
                ))
            .copyWith(
              error: message ?? 'Unexpected error',
              finishedAt: now,
              durationMs: _computeDurationMs(previous?.startedAt, now),
            );
    _entries[id] = updated;
    _notify();
  }

  // Helpers
  List<ApiTrafficEntry> get _sortedEntries {
    return _entries.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  void _notify() {
    final snapshot = _sortedEntries;
    for (final listener in _listeners) {
      listener(snapshot);
    }
  }

  int? _computeDurationMs(DateTime? startedAt, DateTime finishedAt) {
    if (startedAt == null) return null;
    return finishedAt.difference(startedAt).inMilliseconds;
  }

  Map<String, String>? _stringifyMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    return map.map(
      (key, value) => MapEntry(key, value == null ? 'null' : value.toString()),
    );
  }

  String? _stringify(dynamic data) {
    if (data == null) return null;
    // No truncation - save full API responses without limits
    try {
      if (data is String) {
        return data;
      } else if (data is Map || data is List) {
        return const JsonEncoder.withIndent('  ').convert(data);
      } else if (data is Uint8List) {
        return 'Binary data (${data.lengthInBytes} bytes)';
      } else {
        return data.toString();
      }
    } catch (_) {
      return data.toString();
    }
  }

  String _buildUrl(
    String baseUrl,
    String path,
    Map<String, dynamic>? queryParams,
  ) {
    // If path is already a full URL (starts with http:// or https://), use it as-is
    if (path.startsWith('http://') || path.startsWith('https://')) {
      // If query params exist, append them to the existing URL
      if (queryParams != null && queryParams.isNotEmpty) {
        final uri = Uri.tryParse(path);
        if (uri != null) {
          final existingQuery = uri.queryParameters;
          final mergedQuery = {...existingQuery};
          for (final entry in queryParams.entries) {
            if (entry.value != null) {
              mergedQuery[entry.key] = entry.value.toString();
            }
          }
          return uri.replace(queryParameters: mergedQuery).toString();
        }
      }
      return path;
    }

    // Otherwise, combine baseUrl and path
    final buffer = StringBuffer();
    if (baseUrl.isNotEmpty) {
      buffer.write(baseUrl);
    }
    buffer.write(path);
    if (queryParams != null && queryParams.isNotEmpty) {
      final filteredParams = queryParams.entries
          .where((entry) => entry.value != null)
          .map(
            (entry) =>
                '${entry.key}=${Uri.encodeComponent(entry.value.toString())}',
          )
          .join('&');
      buffer.write('?$filteredParams');
    }
    return buffer.toString();
  }
}
