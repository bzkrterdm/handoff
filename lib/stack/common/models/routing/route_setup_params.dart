import 'route_definition.dart';

class RouteSetupParams {
  RouteSetupParams({required this.routeDefinitions});

  /// Definitions of all the routes in the app.
  final List<RouteDefinition> routeDefinitions;
}
