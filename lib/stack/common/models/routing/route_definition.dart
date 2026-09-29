import 'package:flutter/widgets.dart';

class RouteDefinition {
  RouteDefinition({
    required this.routePath,
    required this.routeHandler,
    this.transitionType,
    this.transitionBuilder,
    this.transitionDuration = _defaultTransitionDuration,
  });

  static const _defaultTransitionDuration = Duration(milliseconds: 200);

  /// Route path defined for the page.
  final String routePath;

  /// Route handler to construct the page.
  final RouteHandler routeHandler;

  /// Transition type when page is pushed/popped.
  final RouteTransitionType? transitionType;

  /// Custom transition builder for the page.
  final RouteTransitionsBuilder? transitionBuilder;

  /// Transition duration time. Defaults to 200 ms.
  final Duration transitionDuration;
}

/// Helper definition for route handler function.
typedef RouteHandler = Widget Function(BuildContext? context, dynamic params);

/// The type of transition to use when pushing/popping a route.
///
/// [RouteTransitionType.custom] must also provide a transition when used.
enum RouteTransitionType {
  native,
  nativeModal,
  inFromLeft,
  inFromTop,
  inFromRight,
  inFromBottom,
  fadeIn,
  custom,
  material,
  materialFullScreenDialog,
  cupertino,
  cupertinoFullScreenDialog,
  none,
}
