import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/tasks/presentation/blocs/tasks_cubit.dart';
import '../features/tasks/presentation/ui/pages/tasks_page.dart';
import '../stack/common/models/routing/route_definition.dart';
import '../stack/common/models/routing/route_setup_params.dart';
import '../stack/core/ioc/service_locator.dart';

/// Route table handed to `RouteManager.setup`.
///
/// Add a `static const` name and a [RouteDefinition] per page, then list the
/// definition in [setupParams] — a page that is not listed cannot be pushed.
abstract class RouteConfig {
  static const String homeRoute = '/';

  static final RouteSetupParams setupParams = RouteSetupParams(
    routeDefinitions: [_tasksRouteDefinition],
  );

  /// The page's cubit is provided by the route rather than app wide, so it is
  /// created when the page is pushed and closed when it is popped. The
  /// provider has to sit above the page: the page's controller reads the cubit
  /// from the context it was built with.
  static final RouteDefinition _tasksRouteDefinition = RouteDefinition(
    routePath: homeRoute,
    routeHandler: (_, params) => BlocProvider<TasksCubit>(
      create: (_) => locator<TasksCubit>(),
      child: TasksPage(params: params as Object?),
    ),
  );
}
