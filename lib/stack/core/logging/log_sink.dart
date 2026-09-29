/// A remote (or any out-of-process) destination for log records.
///
/// The stack ships without a concrete sink: logging goes to the console only
/// until an app registers one. Implement this interface to forward records to
/// a telemetry backend, then pass it at startup.
///
/// ```dart
/// class MyTelemetrySink implements LogSink {
///   @override
///   void send(LogEntry entry) {
///     // Forward the entry to wherever it belongs.
///   }
///
///   @override
///   Future<void> flush() async {}
///
///   @override
///   void dispose() {}
/// }
///
/// void main() {
///   locator<Logger>().initialize(sinks: [MyTelemetrySink()]);
/// }
/// ```
abstract interface class LogSink {
  /// Called for every record the app logs with remote logging enabled.
  void send(LogEntry entry);

  /// Pushes any buffered records out. Called by `Logger.dispose`.
  Future<void> flush();

  /// Releases the resources held by the sink.
  void dispose();
}

/// A single log record handed to the registered [LogSink]s.
class LogEntry {
  LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.callerType,
    this.isPageView = false,
    this.additionalProperties,
  });

  /// Severity of the record.
  final LogLevel level;

  /// The message to be logged.
  final String message;

  /// Creation time of the record in UTC.
  final DateTime timestamp;

  /// Runtime type (class name) of the caller, when provided.
  final Type? callerType;

  /// Whether the record represents a page/screen view rather than a trace.
  final bool isPageView;

  /// Extra key/value pairs to be attached to the record.
  final Map<String, Object>? additionalProperties;
}

/// Severity levels a [LogEntry] can have.
enum LogLevel { debug, info, error, critical }
