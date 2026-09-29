import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/stack/core/logging/log_sink.dart';
import 'package:handoff/stack/core/logging/logger.dart';

/// Covers the seam the stack leaves for a telemetry vendor: everything a
/// `LogSink` implementation can rely on.
void main() {
  late _CapturingSink sink;
  late Logger logger;

  setUp(() {
    sink = _CapturingSink();
    logger = LoggerImpl()
      ..initialize(
        sinks: [sink],
        globalProperties: const {'environment': 'test'},
      );
  });

  group('LoggerImpl', () {
    test('forwards a record with caller, level and properties', () {
      logger.info(
        'started',
        callerType: _Caller,
        additionalProperties: const {'attempt': 2},
      );

      expect(sink.entries, hasLength(1));
      final entry = sink.entries.single;
      expect(entry.level, LogLevel.info);
      expect(entry.message, '[@_Caller] started');
      expect(entry.callerType, _Caller);
      expect(entry.isPageView, isFalse);
      expect(entry.additionalProperties, {'environment': 'test', 'attempt': 2});
    });

    test('maps each method to its level', () {
      logger
        ..debug('d')
        ..info('i')
        ..error('e')
        ..critical('c');

      expect(sink.entries.map((entry) => entry.level), [
        LogLevel.debug,
        LogLevel.info,
        LogLevel.error,
        LogLevel.critical,
      ]);
    });

    test('marks a page view apart from a trace', () {
      logger.info('home', informPageView: true);

      expect(sink.entries.single.isPageView, isTrue);
    });

    test('skips the sink when remote logging is off', () {
      logger.error('local only', logRemote: false);

      expect(sink.entries, isEmpty);
    });

    test('flushes and releases the sink on dispose', () async {
      logger.info('before dispose');

      await logger.dispose();

      expect(sink.flushCount, 1);
      expect(sink.isDisposed, isTrue);

      // A disposed logger has no sinks left to forward to.
      logger.info('after dispose');

      expect(sink.entries, hasLength(1));
    });

    test('replaces the sinks of a previous initialize', () {
      final other = _CapturingSink();
      logger.initialize(sinks: [other]);

      logger.info('once');

      expect(sink.entries, isEmpty);
      expect(other.entries, hasLength(1));
    });
  });
}

class _Caller {}

class _CapturingSink implements LogSink {
  final List<LogEntry> entries = [];

  int flushCount = 0;
  bool isDisposed = false;

  @override
  void send(LogEntry entry) => entries.add(entry);

  @override
  Future<void> flush() async => flushCount++;

  @override
  void dispose() => isDisposed = true;
}
