import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/stack/core/analytics/analytics_service.dart';
import 'package:handoff/stack/core/logging/log_sink.dart';
import 'package:handoff/stack/core/logging/logger.dart';

/// Covers the contract a vendor implementation has to honour, through the
/// logging implementation the stack ships with.
void main() {
  late _CapturingSink sink;
  late AnalyticsService analytics;

  setUp(() {
    sink = _CapturingSink();
    final logger = LoggerImpl()..initialize(sinks: [sink]);
    analytics = LoggingAnalyticsService(logger);
  });

  group('LoggingAnalyticsService', () {
    test('tracks an untimed event without duration properties', () {
      analytics.trackEvent('opened_home', section: 'home');

      expect(sink.messages.single, contains('opened_home'));
      expect(sink.messages.single, contains('section: home'));
      expect(
        sink.messages.single,
        isNot(contains(LoggingAnalyticsService.durationParam)),
      );
    });

    test('reports the duration of a tracked event', () {
      analytics
        ..startTracking('checkout')
        ..trackEvent('checkout', timeTracking: true);

      expect(
        sink.messages.single,
        contains(LoggingAnalyticsService.durationParam),
      );
      expect(
        sink.messages.single,
        contains('${LoggingAnalyticsService.timeIntervalParam}: low'),
      );
    });

    test('drops a timed event that was never started', () {
      analytics.trackEvent('checkout', timeTracking: true);

      expect(sink.messages, isEmpty);
    });

    test('stops reporting a duration once the event is tracked', () {
      analytics
        ..startTracking('checkout')
        ..trackEvent('checkout')
        ..trackEvent('checkout');

      expect(
        sink.messages.first,
        contains(LoggingAnalyticsService.durationParam),
      );
      expect(
        sink.messages.last,
        isNot(contains(LoggingAnalyticsService.durationParam)),
      );
    });

    test('attaches default properties to every event', () {
      analytics
        ..setDefaultProperty('region', 'emea')
        ..trackEvent('opened_home');

      expect(sink.messages.single, contains('region: emea'));

      analytics
        ..setDefaultProperty('region', null)
        ..trackEvent('opened_home');

      expect(sink.messages.last, isNot(contains('region')));
    });

    test('tracks a page view', () {
      analytics.trackView('HomePage');

      expect(sink.messages.single, contains('HomePage'));
    });
  });

  group('TimeIntervalType', () {
    test('buckets a duration by its seconds', () {
      expect(TimeIntervalType.find(0), TimeIntervalType.low);
      expect(TimeIntervalType.find(29), TimeIntervalType.low);
      expect(TimeIntervalType.find(30), TimeIntervalType.medium);
      expect(TimeIntervalType.find(119), TimeIntervalType.medium);
      expect(TimeIntervalType.find(120), TimeIntervalType.high);
    });
  });
}

class _CapturingSink implements LogSink {
  final List<String> messages = [];

  @override
  void send(LogEntry entry) => messages.add(entry.message);

  @override
  Future<void> flush() async {}

  @override
  void dispose() {}
}
