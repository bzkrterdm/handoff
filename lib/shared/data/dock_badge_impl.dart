import 'package:flutter/services.dart';

import '../../stack/core/logging/logger.dart';
import '../domain/dock_badge.dart';

/// Talks to `DockBadgeChannel.swift` over a method channel. One AppKit line
/// on the other side, so no plugin.
class DockBadgeImpl implements DockBadge {
  DockBadgeImpl(this._logger);

  static const MethodChannel _channel = MethodChannel('handoff/dock');

  final Logger _logger;
  int? _last;

  @override
  Future<void> setCount(int count) async {
    if (count == _last) return;
    _last = count;
    try {
      await _channel.invokeMethod<void>(
        'setBadge',
        count > 0 ? '$count' : null,
      );
    } on MissingPluginException {
      // Tests and non-macOS hosts have no channel; the badge is cosmetic.
    } on PlatformException catch (error) {
      _logger.error('Dock badge failed: $error', callerType: runtimeType);
    }
  }
}
