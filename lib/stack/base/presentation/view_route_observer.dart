import 'package:flutter/material.dart';

/// Route observer that lets a `ControlledView` know when it is covered by
/// another page and when it shows up again.
///
/// Register it once, or `onVisible`/`onHidden` never fire:
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [ViewRouteObserver.instance],
///   ...
/// );
/// ```
abstract class ViewRouteObserver {
  /// The single observer every view subscribes to.
  static final RouteObserver<ModalRoute<void>> instance =
      RouteObserver<ModalRoute<void>>();
}
