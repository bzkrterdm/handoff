import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/stack/core/analytics/analytics_service.dart';
import 'package:handoff/stack/core/ioc/service_locator.dart';
import 'package:handoff/stack/core/logging/logger.dart';

void main() {
  group('ServiceLocator', () {
    test('registers the core services and the app ones after them', () {
      final registered = <String>[];

      locator.initialize(external: () => registered.add('external'));

      expect(registered, ['external']);
      expect(locator<Logger>(), isA<LoggerImpl>());
      expect(locator<AnalyticsService>(), isA<LoggingAnalyticsService>());
    });

    test('lets an app swap a core registration', () {
      locator.registerOverride<AnalyticsService>(
        () => _VendorAnalyticsService(locator()),
      );

      expect(locator<AnalyticsService>(), isA<_VendorAnalyticsService>());
    });

    test('registers a type that was never registered before', () {
      expect(locator.isRegistered<_Unregistered>(), isFalse);

      locator.registerOverride<_Unregistered>(_Unregistered.new);

      expect(locator<_Unregistered>(), isA<_Unregistered>());
    });
  });
}

class _VendorAnalyticsService extends LoggingAnalyticsService {
  _VendorAnalyticsService(super.logger);
}

class _Unregistered {}
