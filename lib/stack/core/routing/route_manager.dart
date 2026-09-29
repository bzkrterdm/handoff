import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../common/models/routing/route_definition.dart';
import '../../common/models/routing/route_setup_params.dart';
import '../logging/logger.dart';

/// A tool to manage navigation between routes.
abstract class RouteManager {
  /// This should be given to MaterialApp.onGenerateRoute.
  Route<dynamic>? Function(RouteSettings)? get generator;

  /// A key to be used when building the [Navigator].
  ///
  /// If a [navigatorKey] is specified, the [Navigator] can be directly
  /// manipulated without first obtaining it from a [BuildContext] via
  /// [Navigator.of]: from the [navigatorKey], use the [GlobalKey.currentState]
  /// getter.
  GlobalKey<NavigatorState> get navigatorKey;

  /// Sets up all the route definitions by [setupParams].
  /// To be called in main before runApp.
  ///
  /// Example usage:
  ///
  /// ```dart
  /// abstract class RouteConfig {
  ///   static const route1 = 'route1';
  ///   static const route2 = 'route2';
  ///
  ///   static final setupParams = RouteSetupParams(
  ///     routeDefinitions: [
  ///       _routeDefinition1,
  ///       _routeDefinition2,
  ///     ],
  ///   );
  ///
  ///   static final _routeDefinition1 = RouteDefinition(
  ///     routePath: route1,
  ///     routeHandler: (context, params) {
  ///       return Page1();
  ///     },
  ///     transitionType: RouteTransitionType.inFromLeft,
  ///   );
  ///   static final _routeDefinition2 = RouteDefinition(
  ///     routePath: route2,
  ///     routeHandler: (context, params) {
  ///       return Page2();
  ///     },
  ///     transitionType: RouteTransitionType.inFromRight,
  ///   );
  /// }
  ///
  /// void main() {
  ///   routeManager.setup(RouteConfig.setupParams);
  /// }
  /// ```
  void setup(RouteSetupParams setupParams);

  /// Gets the current route.
  String? getCurrentRoute(BuildContext context);

  /// Navigates to the given [route] with optional [params].
  Future<void> goRoute(BuildContext context, String route, {Object? params});

  /// Navigates to the given [route]
  /// removing all the others with optional [params].
  Future<void> goRouteAsRoot(
    BuildContext context,
    String route, {
    Object? params,
  });

  /// Navigates back to the previous route.
  void goBack(BuildContext context);

  /// Navigates back to a [route] removing all the routes in between.
  void returnRoute(BuildContext context, String route);

  /// Replaces the current route with the given [route].
  Future<void> replaceRoute(
    BuildContext context,
    String route, {
    Object? params,
  });

  /// Refreshes the current route.
  Future<void> refreshRoute(BuildContext context, {Object? params});
}

/// RouteManager Implementation
///
/// Builds the routes itself on top of [Navigator]'s named routes, so the app
/// needs no routing package: [setup] fills a route table and [generator] is
/// the `onGenerateRoute` callback that resolves a name to a [PageRoute] with
/// the transition its definition asks for.
class RouteManagerImpl implements RouteManager {
  RouteManagerImpl(this._logger);

  final Logger _logger;

  final _definitions = <String, RouteDefinition>{};
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _transitionTimer = Stopwatch();

  bool _canNavigateForward = true;

  @override
  Route<dynamic>? Function(RouteSettings)? get generator => _generateRoute;

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  @override
  void setup(RouteSetupParams setupParams) {
    _definitions
      ..clear()
      ..addEntries(
        setupParams.routeDefinitions.map(
          (definition) => MapEntry(definition.routePath, definition),
        ),
      );
  }

  @override
  String? getCurrentRoute(BuildContext context) {
    String? currentRoute;
    Navigator.of(context).popUntil((route) {
      currentRoute = route.settings.name;
      return true;
    });
    return currentRoute;
  }

  @override
  Future<void> goRoute(
    BuildContext context,
    String route, {
    Object? params,
  }) async {
    try {
      if (!_canNavigateForward) return;
      _restartTransitionTimer();
      await Navigator.of(context).pushNamed(route, arguments: params);
    } catch (e) {
      _logger.error(
        'Navigating to $route failed.\n${e.toString()}',
        callerType: runtimeType,
      );
    }
  }

  @override
  Future<void> goRouteAsRoot(
    BuildContext context,
    String route, {
    Object? params,
  }) async {
    try {
      if (!_canNavigateForward) return;
      _restartTransitionTimer();
      await Navigator.of(context).pushNamedAndRemoveUntil(
        route,
        arguments: params,
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      _logger.error(
        'Navigating to $route as root failed.\n${e.toString()}',
        callerType: runtimeType,
      );
    }
  }

  @override
  void goBack(BuildContext context) {
    try {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _logger.error(
        'Navigating back failed.\n${e.toString()}',
        callerType: runtimeType,
      );
    }
  }

  @override
  void returnRoute(BuildContext context, String route) {
    try {
      Navigator.of(context).popUntil(ModalRoute.withName(route));
    } catch (e) {
      _logger.error(
        'Returning to $route failed.\n${e.toString()}',
        callerType: runtimeType,
      );
    }
  }

  @override
  Future<void> replaceRoute(
    BuildContext context,
    String route, {
    Object? params,
  }) {
    try {
      return Navigator.of(
        context,
      ).pushReplacementNamed(route, arguments: params);
    } catch (e) {
      _logger.error(
        'Replacing route with $route failed.\n${e.toString()}',
        callerType: runtimeType,
      );
    }
    return Future.value();
  }

  @override
  Future<void> refreshRoute(BuildContext context, {Object? params}) {
    try {
      // Get the current route name.
      final currentRoute = getCurrentRoute(context);
      if (currentRoute == null) {
        _logger.error(
          'Refreshing current route failed '
          'as route name could not be determined.',
          callerType: runtimeType,
        );
        return Future.value();
      }
      // Refresh the current route.
      return Navigator.of(
        context,
      ).pushReplacementNamed(currentRoute, arguments: params);
    } catch (e) {
      _logger.error(
        'Refreshing current route failed.\n${e.toString()}',
        callerType: runtimeType,
      );
    }
    return Future.value();
  }

  // Helpers
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    final definition = _definitions[settings.name];
    if (definition == null) {
      _logger.error(
        'Route ${settings.name} is not defined.',
        callerType: runtimeType,
      );
      return null;
    }
    return _buildRoute(definition, settings);
  }

  Route<dynamic> _buildRoute(
    RouteDefinition definition,
    RouteSettings settings,
  ) {
    Widget buildPage(BuildContext context) {
      return _buildRouteWidget(context, definition, settings.arguments);
    }

    switch (definition.transitionType ?? RouteTransitionType.native) {
      case RouteTransitionType.native:
      case RouteTransitionType.material:
        return MaterialPageRoute<dynamic>(
          settings: settings,
          builder: buildPage,
        );
      case RouteTransitionType.nativeModal:
      case RouteTransitionType.materialFullScreenDialog:
        return MaterialPageRoute<dynamic>(
          settings: settings,
          fullscreenDialog: true,
          builder: buildPage,
        );
      case RouteTransitionType.cupertino:
        return CupertinoPageRoute<dynamic>(
          settings: settings,
          builder: buildPage,
        );
      case RouteTransitionType.cupertinoFullScreenDialog:
        return CupertinoPageRoute<dynamic>(
          settings: settings,
          fullscreenDialog: true,
          builder: buildPage,
        );
      case RouteTransitionType.none:
        return PageRouteBuilder<dynamic>(
          settings: settings,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, _, _) => buildPage(context),
        );
      case RouteTransitionType.custom:
        return PageRouteBuilder<dynamic>(
          settings: settings,
          transitionDuration: definition.transitionDuration,
          reverseTransitionDuration: definition.transitionDuration,
          pageBuilder: (context, _, _) => buildPage(context),
          transitionsBuilder:
              definition.transitionBuilder ?? _buildFadeTransition,
        );
      case RouteTransitionType.fadeIn:
        return PageRouteBuilder<dynamic>(
          settings: settings,
          transitionDuration: definition.transitionDuration,
          reverseTransitionDuration: definition.transitionDuration,
          pageBuilder: (context, _, _) => buildPage(context),
          transitionsBuilder: _buildFadeTransition,
        );
      case RouteTransitionType.inFromLeft:
      case RouteTransitionType.inFromRight:
      case RouteTransitionType.inFromTop:
      case RouteTransitionType.inFromBottom:
        return PageRouteBuilder<dynamic>(
          settings: settings,
          transitionDuration: definition.transitionDuration,
          reverseTransitionDuration: definition.transitionDuration,
          pageBuilder: (context, _, _) => buildPage(context),
          transitionsBuilder: (context, animation, _, child) {
            return _buildSlideTransition(
              definition.transitionType!,
              animation,
              child,
            );
          },
        );
    }
  }

  Widget _buildFadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }

  Widget _buildSlideTransition(
    RouteTransitionType transitionType,
    Animation<double> animation,
    Widget child,
  ) {
    final begin = switch (transitionType) {
      RouteTransitionType.inFromLeft => const Offset(-1, 0),
      RouteTransitionType.inFromRight => const Offset(1, 0),
      RouteTransitionType.inFromTop => const Offset(0, -1),
      _ => const Offset(0, 1),
    };
    return SlideTransition(
      position: Tween<Offset>(
        begin: begin,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: child,
    );
  }

  Widget _buildRouteWidget(
    BuildContext context,
    RouteDefinition definition,
    Object? params,
  ) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _blockNavigateForwardUntilTransitionCompletes(
            definition.transitionDuration,
          );
        }
      },
      // Construct the page as per the definition.
      child: definition.routeHandler(context, params),
    );
  }

  void _blockNavigateForwardUntilTransitionCompletes(
    Duration transitionDuration,
  ) {
    _canNavigateForward = false;
    _transitionTimer.stop();

    const delayOffsetMs = 50;
    final delayInMilliseconds = min(
      transitionDuration.inMilliseconds + delayOffsetMs,
      _transitionTimer.elapsedMilliseconds + delayOffsetMs,
    );
    Future.delayed(
      Duration(milliseconds: delayInMilliseconds),
      () => _canNavigateForward = true,
    );
  }

  void _restartTransitionTimer() {
    _transitionTimer.reset();
    _transitionTimer.start();
  }

  // - Helpers
}
