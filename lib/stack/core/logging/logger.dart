import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'log_sink.dart';

/// A tool to log messages for different purposes such as debug, crash etc.
///
/// Local logging goes to the console in debug builds. Remote logging is
/// delegated to the [LogSink]s given to [initialize], so the stack itself
/// stays free of any telemetry vendor.
abstract class Logger {
  static const String errorPrefix = '[E]';
  static const String infoPrefix = '[I]';
  static const String criticalPrefix = '[C]';
  static const String debugPrefix = '[D]';

  /// To be called in main before runApp.
  /// [sinks] are the remote destinations to forward the records to.
  /// [globalProperties] are attached to every record.
  void initialize({List<LogSink> sinks, Map<String, Object> globalProperties});

  /// Logs [message] for debug purposes. Also, [callerType] can be provided
  /// to specify the caller runtime type (class name) in the log header.
  /// [logRemote] toggles remote logging.
  /// [logLocal] toggles local logging.
  /// [additionalProperties] adds extra properties to the log.
  void debug(
    String message, {
    Type? callerType,
    bool logRemote = true,
    bool logLocal = true,
    Map<String, Object>? additionalProperties,
  });

  /// Logs [message] for general purpose. Also, [callerType] can be provided
  /// to specify the caller runtime type (class name) in the log header.
  /// [logRemote] toggles remote logging.
  /// [logLocal] toggles local logging.
  /// [informPageView] marks the record as a page view instead of a trace.
  /// [additionalProperties] adds extra properties to the log.
  void info(
    String message, {
    Type? callerType,
    bool logRemote = true,
    bool logLocal = true,
    bool informPageView = false,
    Map<String, Object>? additionalProperties,
  });

  /// Logs [message] for error cases. Also, [callerType] can be provided
  /// to specify the caller runtime type (class name) in the log header.
  /// [logRemote] toggles remote logging.
  /// [logLocal] toggles local logging.
  /// [additionalProperties] adds extra properties to the log.
  void error(
    String message, {
    Type? callerType,
    bool logRemote = true,
    bool logLocal = true,
    Map<String, Object>? additionalProperties,
  });

  /// Logs [message] for crash cases. Also, [callerType] can be provided
  /// to specify the caller runtime type (class name) in the log header.
  /// [logRemote] toggles remote logging.
  /// [logLocal] toggles local logging.
  /// [additionalProperties] adds extra properties to the log.
  void critical(
    String message, {
    Type? callerType,
    bool logRemote = true,
    bool logLocal = true,
    Map<String, Object>? additionalProperties,
  });

  /// Disposes the logger flushing the registered sinks.
  /// This should be called when the app is closed.
  Future<void> dispose();
}

/// Logger Implementation
class LoggerImpl implements Logger {
  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm:ss:S');

  final List<LogSink> _sinks = [];
  final Map<String, Object> _globalProperties = {};

  @override
  void initialize({
    List<LogSink> sinks = const [],
    Map<String, Object> globalProperties = const {},
  }) {
    _sinks
      ..clear()
      ..addAll(sinks);
    _globalProperties
      ..clear()
      ..addAll(globalProperties);
  }

  @override
  void debug(
    String message, {
    Type? callerType,
    bool logRemote = true,
    bool logLocal = true,
    Map<String, Object>? additionalProperties,
  }) {
    _log(
      LogLevel.debug,
      Logger.debugPrefix,
      message,
      callerType: callerType,
      logRemote: logRemote,
      logLocal: logLocal,
      additionalProperties: additionalProperties,
    );
  }

  @override
  void info(
    String message, {
    Type? callerType,
    bool logRemote = true,
    bool logLocal = true,
    bool informPageView = false,
    Map<String, Object>? additionalProperties,
  }) {
    _log(
      LogLevel.info,
      Logger.infoPrefix,
      message,
      callerType: callerType,
      logRemote: logRemote,
      logLocal: logLocal,
      informPageView: informPageView,
      additionalProperties: additionalProperties,
    );
  }

  @override
  void error(
    String message, {
    Type? callerType,
    bool logRemote = true,
    bool logLocal = true,
    Map<String, Object>? additionalProperties,
  }) {
    _log(
      LogLevel.error,
      Logger.errorPrefix,
      message,
      callerType: callerType,
      logRemote: logRemote,
      logLocal: logLocal,
      additionalProperties: additionalProperties,
    );
  }

  @override
  void critical(
    String message, {
    Type? callerType,
    bool logRemote = true,
    bool logLocal = true,
    Map<String, Object>? additionalProperties,
  }) {
    _log(
      LogLevel.critical,
      Logger.criticalPrefix,
      message,
      callerType: callerType,
      logRemote: logRemote,
      logLocal: logLocal,
      additionalProperties: additionalProperties,
    );
  }

  @override
  Future<void> dispose() async {
    for (final sink in _sinks) {
      await sink.flush();
      sink.dispose();
    }
    _sinks.clear();
  }

  // Helpers
  void _log(
    LogLevel level,
    String prefix,
    String message, {
    Type? callerType,
    required bool logRemote,
    required bool logLocal,
    bool informPageView = false,
    Map<String, Object>? additionalProperties,
  }) {
    if (logRemote && _sinks.isNotEmpty) {
      final entry = LogEntry(
        level: level,
        message: _buildRemoteMessageLine(message, callerType),
        timestamp: DateTime.now().toUtc(),
        callerType: callerType,
        isPageView: informPageView,
        additionalProperties: _buildAdditionalProperties(additionalProperties),
      );
      for (final sink in _sinks) {
        sink.send(entry);
      }
    }
    if (kDebugMode && logLocal) {
      log(_buildLocalMessageLine(prefix, message, callerType));
    }
  }

  String _buildRemoteMessageLine(String message, Type? callerType) {
    final callerTypeText = callerType != null ? '[@$callerType] ' : '';
    return '$callerTypeText$message';
  }

  String _buildLocalMessageLine(
    String prefix,
    String message,
    Type? callerType,
  ) {
    final callerTypeText = callerType != null ? ' [@$callerType]' : '';
    return '$prefix [${_getDateTime()}]$callerTypeText $message';
  }

  String _getDateTime() {
    return _dateFormat.format(DateTime.now().toUtc());
  }

  Map<String, Object> _buildAdditionalProperties(
    Map<String, Object>? additionalProperties,
  ) {
    return {..._globalProperties, ...?additionalProperties};
  }

  // - Helpers
}
