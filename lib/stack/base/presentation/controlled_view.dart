// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';

import '../../core/ioc/service_locator.dart';
import 'controller.dart';
import 'controller_provider.dart';
import 'view_route_observer.dart';

/// Base class for pages/sub-pages.
///
/// Every page/sub-page should extend this class as an example as below.
///
/// ```dart
/// class FooPage extends ControlledView<FooController, Object> {
///   FooPage({super.key, super.params});
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       body: Container(),
///       floatingActionButton: FloatingActionButton(
///         onPressed: () {
///           // Use controller to trigger events.
///           controller.doSomething();
///         },
///       ),
///     );
///   }
/// }
///
/// class FooController extends Controller<Object> {
///   FooController(
///     super.logger,
///     super.localizor,
///     super.routeManager,
///     super.popupManager,
///   );
///
///   void doSomething() {
///     // Do something.
///   }
/// }
/// ```
///
/// [onVisible] and [onHidden] need [ViewRouteObserver.instance] registered in
/// `MaterialApp.navigatorObservers`.
///
/// See also:
///
/// * [Controller], a base to components that hold presentation logic.
abstract class ControlledView<
  TController extends Controller<TParams>,
  TParams extends Object
>
    extends StatefulWidget {
  ControlledView({super.key, this.params})
    : controller = locator<TController>();

  /// Optional parameters that can be passed during navigation.
  final TParams? params;

  /// Controller of this view. It is to be used as a presentation logic holder.
  late final TController controller;

  /// Whether a back request is allowed to pop this view. Both this and
  /// [Controller.canGoBack] must be true for the pop to go through.
  ///
  /// Read synchronously by [PopScope]: drive it from a field the view rebuilds
  /// on, not from an async check.
  @protected
  bool get canGoBack => true;

  /// Called when the view is activated on start or resume.
  @protected
  @mustCallSuper
  void onActivate() {}

  /// Called once when the view is initialized.
  @protected
  @mustCallSuper
  void onStart() {
    controller.logger.info(
      '${_getHashCodeString()} - onStart',
      callerType: runtimeType,
      informPageView: true,
      additionalProperties: params != null
          ? {'params': params.toString()}
          : null,
    );
  }

  /// Called once when the view started and whenever the dependencies change.
  @protected
  @mustCallSuper
  void onPostStart() {}

  /// Called after build is finished.
  @protected
  @mustCallSuper
  void onPostBuild() {}

  /// Called when the view is visible back from pause.
  @protected
  @mustCallSuper
  void onResume() {
    controller.logger.info(
      '${_getHashCodeString()} - onResume',
      callerType: runtimeType,
    );
  }

  /// Called when the view is visible on screen.
  @protected
  @mustCallSuper
  void onVisible() {}

  /// Called when the view is hidden on screen.
  @protected
  @mustCallSuper
  void onHidden() {}

  /// Called when the view goes invisible and running in the background.
  @protected
  @mustCallSuper
  void onPause() {
    controller.logger.info(
      '${_getHashCodeString()} - onPause',
      callerType: runtimeType,
    );
  }

  /// Called when the view is disposed. The difference between onStop and
  /// onClose is that onClose is called when the app is detached but
  /// onStop means the view is popped from the navigation stack.
  @protected
  @mustCallSuper
  void onStop() {
    controller.logger.info(
      '${_getHashCodeString()} - onStop',
      callerType: runtimeType,
    );
  }

  /// Called when the app is detached which usually happens when
  /// back button is pressed.
  @protected
  @mustCallSuper
  void onClose() {
    controller.logger.info(
      '${_getHashCodeString()} - onClose',
      callerType: runtimeType,
    );
  }

  /// Called when the view is deactivated on pause or close.
  @protected
  @mustCallSuper
  void onDeactivate() {}

  /// Called when a back request reached this view. [didPop] is false when
  /// [canGoBack] blocked the pop.
  @protected
  @mustCallSuper
  Future<void> onBackRequest({required bool didPop}) async {
    controller.logger.info(
      '${_getHashCodeString()} - onBackRequest (didPop: $didPop)',
      callerType: runtimeType,
    );
  }

  @override
  // ignore: library_private_types_in_public_api
  _ControlledViewState<TController> createState() {
    // Create the view state with all the callbacks.
    // ignore: no_logic_in_create_state
    return _ControlledViewState(
      controller,
      buildView: (context) {
        return ControllerProvider(
          controller: controller,
          child: PopScope(
            // Handle back press. An inactive view never pops itself.
            canPop: controller.isActive && canGoBack && controller.canGoBack,
            onPopInvokedWithResult: (didPop, _) {
              onBackRequest(didPop: didPop);
              controller.onBackRequest(didPop: didPop);
            },
            child: build(context),
          ),
        );
      },
      onActivate: onActivate,
      onInitState: onStart,
      onPostInitState: onPostStart,
      onPostBuild: onPostBuild,
      onResume: onResume,
      onVisible: onVisible,
      onHidden: onHidden,
      onPause: onPause,
      onDispose: onStop,
      onDetach: onClose,
      onDeactivate: onDeactivate,
    );
  }

  /// Describes the widget to be constructed.
  @protected
  Widget build(BuildContext context);

  // Helpers
  String _getHashCodeString() {
    return '0x${hashCode.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  // - Helpers
}

// View state that handles all the lifecycle events.
class _ControlledViewState<TController extends Controller>
    extends State<ControlledView>
    with
        RouteAware,
        WidgetsBindingObserver,
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin {
  _ControlledViewState(
    this._controller, {
    required this.buildView,
    required this.onActivate,
    required this.onInitState,
    required this.onPostInitState,
    required this.onPostBuild,
    required this.onResume,
    required this.onVisible,
    required this.onHidden,
    required this.onPause,
    required this.onDispose,
    required this.onDetach,
    required this.onDeactivate,
  });

  final Controller _controller;
  final Widget Function(BuildContext context) buildView;
  final void Function() onActivate;
  final void Function() onInitState;
  final void Function() onPostInitState;
  final void Function() onPostBuild;
  final void Function() onResume;
  final void Function() onVisible;
  final void Function() onHidden;
  final void Function() onPause;
  final void Function() onDispose;
  final void Function() onDetach;
  final void Function() onDeactivate;

  bool _isAppInBackground = false;
  bool _isVisible = false;
  ModalRoute<void>? _subscribedRoute;

  @override
  bool get wantKeepAlive => _controller.keepViewAlive;

  @override
  void initState() {
    super.initState();
    // Share BuildContext with the controller.
    _controller.context = context;
    // Pass optional params to the controller.
    _controller.params = widget.params;
    // Set ticker provider for the controller.
    _controller.vsync = this;
    onActivate();
    _controller.onActivate();
    onInitState();
    _controller.onStart();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onPostBuild();
      _controller.onReady();
    });
  }

  @override
  void didUpdateWidget(ControlledView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.params = widget.params;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToRouteChanges();
    if (!_controller.isActive) {
      return;
    }
    onPostInitState();
    _controller.onPostStart();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        onDeactivate();
        _controller.onDeactivate();
        break;
      case AppLifecycleState.resumed:
        // For some reason, this callback is called twice when the app is
        // resumed from background. This is a workaround to prevent it.
        if (!_isAppInBackground) return;
        onActivate();
        _controller.onActivate();
        onResume();
        _controller.onResume();
        _isAppInBackground = false;
        break;
      case AppLifecycleState.paused:
        // For some reason, this callback is called twice when the app is
        // paused to background. This is a workaround to prevent it.
        if (_isAppInBackground) return;
        onPause();
        _controller.onPause();
        _isAppInBackground = true;
        break;
      case AppLifecycleState.detached:
        onDetach();
        _controller.onClose();
        break;
      default:
        break;
    }
  }

  /// This view became the top route.
  @override
  void didPush() => _updateVisibility(isVisible: true);

  /// The route above this view was popped, so it is on top again.
  @override
  void didPopNext() => _updateVisibility(isVisible: true);

  /// Another route was pushed on top of this view.
  @override
  void didPushNext() => _updateVisibility(isVisible: false);

  /// This view itself was popped.
  @override
  void didPop() => _updateVisibility(isVisible: false);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return buildView(context);
  }

  @override
  void dispose() {
    if (_subscribedRoute != null) {
      ViewRouteObserver.instance.unsubscribe(this);
      _subscribedRoute = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _controller.onStop();
    onDispose();
    super.dispose();
  }

  // Helpers
  void _subscribeToRouteChanges() {
    final route = ModalRoute.of<void>(context);
    if (route == null || route == _subscribedRoute) return;
    if (_subscribedRoute != null) {
      ViewRouteObserver.instance.unsubscribe(this);
    }
    _subscribedRoute = route;
    // Subscribing reports the current route as pushed, which is what makes
    // the first onVisible fire.
    ViewRouteObserver.instance.subscribe(this, route);
  }

  void _updateVisibility({required bool isVisible}) {
    if (_isVisible == isVisible) return;
    _isVisible = isVisible;
    if (isVisible) {
      onVisible();
      _controller.onVisible();
      return;
    }
    onHidden();
    _controller.onHidden();
  }

  // - Helpers
}
