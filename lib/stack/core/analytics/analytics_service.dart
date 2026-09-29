import '../logging/logger.dart';

/// A tool to track product analytics events and screen views.
///
/// The stack ships with [LoggingAnalyticsService] only, which writes the
/// events to the [Logger]. Wire a vendor SDK (Firebase, Amplitude, Segment
/// etc.) by implementing this interface in the app and registering it in the
/// service locator instead.
abstract class AnalyticsService {
  AnalyticsService(this.logger);

  final Logger logger;

  /// Identifies the current user, or clears it when [userId] is null.
  void changeUserId(String? userId);

  /// Sets a user scoped property, or clears it when [value] is null.
  void setUserProperty(String name, String? value);

  /// Attaches [value] to every subsequent event, or clears it when null.
  void setDefaultProperty(String name, Object? value);

  /// Starts a stopwatch for [eventKey] to be reported as the event duration
  /// when [trackEvent] is called with the same key.
  void startTracking(String eventKey);

  /// Extends the tracked duration of [eventKey] by [duration], or of every
  /// tracked event when [eventKey] is omitted. Useful to discard the time
  /// the app spent in the background.
  void addIdleTime(Duration duration, {String? eventKey});

  /// Tracks [currentEvent] with the optional details below.
  /// [endEvent] names the event that completed the tracked flow.
  /// [section] names the app section the event originates from.
  /// [actionType] names the kind of interaction the event represents.
  /// [timeTracking] drops the event unless [startTracking] was called for it.
  /// [parameters] adds extra properties to the event.
  void trackEvent(
    String currentEvent, {
    String? endEvent,
    String? section,
    String? actionType,
    bool timeTracking = false,
    Map<String, Object>? parameters,
  });

  /// Tracks a view of the page named [pageName].
  void trackView(String pageName);

  /// Releases the resources held by the service.
  void dispose();
}

/// An [AnalyticsService] that logs the events instead of sending them out.
/// It is the default registration so that instrumentation can be written
/// before a vendor is picked.
class LoggingAnalyticsService extends AnalyticsService {
  LoggingAnalyticsService(super.logger);

  static const String actionTypeParam = 'action_type';
  static const String durationParam = 'duration_ms';
  static const String endEventParam = 'end_event';
  static const String sectionParam = 'section';
  static const String timeDiffParam = 'event_time_diff';
  static const String timeIntervalParam = 'event_time_interval';

  final Map<String, DateTime> _eventTimestampMap = {};
  final Map<String, Object> _defaultProperties = {};

  @override
  void changeUserId(String? userId) {
    logger.info('[Analytics] | User id: ${userId ?? 'cleared'}');
  }

  @override
  void setUserProperty(String name, String? value) {
    logger.info('[Analytics] | User property: $name = $value');
  }

  @override
  void setDefaultProperty(String name, Object? value) {
    if (value == null) {
      _defaultProperties.remove(name);
    } else {
      _defaultProperties[name] = value;
    }
  }

  @override
  void startTracking(String eventKey) {
    _eventTimestampMap[eventKey] = DateTime.now();
  }

  @override
  void addIdleTime(Duration duration, {String? eventKey}) {
    if (eventKey != null) {
      final startedAt = _eventTimestampMap[eventKey];
      if (startedAt != null) {
        _eventTimestampMap[eventKey] = startedAt.add(duration);
      }
      return;
    }
    _eventTimestampMap.forEach((key, value) {
      _eventTimestampMap[key] = value.add(duration);
    });
  }

  @override
  void trackEvent(
    String currentEvent, {
    String? endEvent,
    String? section,
    String? actionType,
    bool timeTracking = false,
    Map<String, Object>? parameters,
  }) {
    final params = <String, Object>{..._defaultProperties, ...?parameters};
    final startedAt = _eventTimestampMap[currentEvent];
    if (startedAt == null && timeTracking) return;

    if (startedAt != null) {
      final duration = DateTime.now().difference(startedAt);
      final durationSeconds = duration.inSeconds;
      params[timeDiffParam] = durationSeconds;
      params[timeIntervalParam] = TimeIntervalType.find(durationSeconds).name;
      params[durationParam] = duration.inMilliseconds;
      _eventTimestampMap.remove(currentEvent);
    }
    if (endEvent != null) params[endEventParam] = endEvent;
    if (section != null) params[sectionParam] = section;
    if (actionType != null) params[actionTypeParam] = actionType;

    logger.info(
      '[Analytics] | Event tracked: $currentEvent, Properties: $params',
    );
  }

  @override
  void trackView(String pageName) {
    logger.info('[Analytics] | Page view tracked: $pageName');
  }

  @override
  void dispose() {
    _eventTimestampMap.clear();
    _defaultProperties.clear();
  }
}

/// Coarse buckets for event durations, reported alongside the exact value so
/// that events can be grouped without post-processing.
enum TimeIntervalType {
  low,
  medium,
  high;

  static const int highLimit = 120;
  static const int lowLimit = 30;

  static TimeIntervalType find(int seconds) {
    if (seconds < lowLimit) {
      return TimeIntervalType.low;
    } else if (seconds < highLimit) {
      return TimeIntervalType.medium;
    }
    return TimeIntervalType.high;
  }
}
