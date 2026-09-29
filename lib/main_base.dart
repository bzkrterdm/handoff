// ignore_for_file: prefer-static-class

import 'dart:async';

import 'package:flutter/material.dart';

import 'configs/app_config.dart';
import 'configs/dependency/dependency_config.dart';
import 'configs/env/env_config.dart';
import 'configs/localization_config.dart';
import 'configs/route_config.dart';
import 'shared/presentation/theme/app_theme.dart';
import 'stack/base/data/local_storage.dart';
import 'stack/base/presentation/view_route_observer.dart';
import 'stack/core/ioc/service_locator.dart';
import 'stack/core/localization/dynamic_localization.dart';
import 'stack/core/localization/localizor.dart';
import 'stack/core/logging/logger.dart';
import 'stack/core/network/api_manager.dart';
import 'stack/core/routing/route_manager.dart';
import 'stack/core/theme/dynamic_theme.dart';
import 'stack/core/theme/theme_manager.dart';

/// Starts the app for the given [env]. Every entry point under `lib/` is a
/// one liner that calls this with its own [EnvConfig].
void mainBase(EnvConfig env) {
  // Run the app in a zone so that uncaught Dart errors are logged too.
  runZonedGuarded(() async {
    await _initializeComponents(env);
    // Handle Flutter errors.
    FlutterError.onError = _onFlutterError;
    runApp(
      MainApp(
        localizor: locator<Localizor>(),
        routeManager: locator<RouteManager>(),
        logger: locator<Logger>(),
        // Read the saved theme mode here to prevent a flash at start.
        themeMode: await locator<ThemeManager>().getThemeMode(),
      ),
    );
  }, _onDartError);
}

/// Root widget wiring the stack into [MaterialApp].
class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    required this.localizor,
    required this.routeManager,
    required this.logger,
    this.themeMode,
  });

  final Localizor localizor;
  final RouteManager routeManager;
  final Logger logger;
  final ThemeMode? themeMode;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) {
    return DynamicLocalization(
      path: LocalizationConfig.assetsPath,
      supportedLocales: LocalizationConfig.supportedLocales,
      // No start locale: the saved choice wins, else the device language.
      fallbackLocale: LocalizationConfig.fallbackLocale,
      useFallbackTranslations: true,
      useOnlyLangCode: LocalizationConfig.useOnlyLangCode,
      child: DynamicTheme(
        initialMode: widget.themeMode ?? ThemeMode.system,
        builder: _buildMaterialApp,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_disposeComponents());
    super.dispose();
  }

  // Helpers
  Widget _buildMaterialApp(ThemeMode themeMode) {
    return _MaterialApp(
      themeMode: themeMode,
      localizor: widget.localizor,
      routeManager: widget.routeManager,
    );
  }

  Future<void> _disposeComponents() async {
    await LocalStorage.dispose();
    await widget.logger.dispose();
  }

  // - Helpers
}

/// The app itself, as a widget rather than a method.
///
/// The indirection is load bearing: `Localizor` resolves its delegates, locale
/// and supported locales from the nearest `EasyLocalization` ancestor, so it
/// has to be handed a context *below* `DynamicLocalization`. Building the
/// `MaterialApp` inside `_MainAppState` would hand it that state's own
/// context, which sits above the wrapper, and the lookup fails on a null.
class _MaterialApp extends StatelessWidget {
  const _MaterialApp({
    required this.themeMode,
    required this.localizor,
    required this.routeManager,
  });

  final ThemeMode themeMode;
  final Localizor localizor;
  final RouteManager routeManager;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (_) => localizor.tr(AppConfig.titleKey),
      // Localization
      localizationsDelegates: localizor.getLocalizationDelegates(context),
      supportedLocales: localizor.getSupportedLocales(context),
      locale: localizor.getLocale(context),
      // Theme
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Navigation
      onGenerateRoute: routeManager.generator,
      navigatorKey: routeManager.navigatorKey,
      // Lets ControlledView report onVisible/onHidden.
      navigatorObservers: [ViewRouteObserver.instance],
      initialRoute: RouteConfig.homeRoute,
    );
  }
}

Future<void> _initializeComponents(EnvConfig env) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Service locator must be initialized before the other components. The env
  // config goes in first, so that anything registered after it can read it.
  locator.initialize(
    external: () {
      locator.registerSingleton<EnvConfig>(env);
      DependencyConfig.register();
    },
  );
  await locator<Localizor>().initialize();
  locator<Logger>().initialize(
    sinks: env.logSinks,
    globalProperties: env.logProperties,
  );
  locator<RouteManager>().setup(RouteConfig.setupParams);
  locator<ApiManager>().setup(env.apiSetupParams);
}

void _onFlutterError(FlutterErrorDetails error) {
  FlutterError.presentError(error);
  locator<Logger>().critical(error.toString(minLevel: DiagnosticLevel.error));
}

void _onDartError(Object error, StackTrace stack) {
  locator<Logger>().critical('${error.toString()}\n${stack.toString()}');
}
