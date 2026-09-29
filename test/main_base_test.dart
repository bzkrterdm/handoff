import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/configs/dependency/dependency_config.dart';
import 'package:handoff/configs/env/env_config.dart';
import 'package:handoff/configs/env/env_configs.dart';
import 'package:handoff/configs/route_config.dart';
import 'package:handoff/main_base.dart';
import 'package:handoff/stack/core/ioc/service_locator.dart';
import 'package:handoff/stack/core/localization/localizor.dart';
import 'package:handoff/stack/core/logging/logger.dart';
import 'package:handoff/stack/core/network/api_manager.dart';
import 'package:handoff/stack/core/routing/route_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fixtures/task_fixtures.dart';

/// Boots the real widget tree — every registration resolved, translations
/// loaded from the asset bundle, the theme wrapper in place, the initial
/// route generated and a real task folder read.
///
/// This is the test that catches wiring, which unit tests cannot: a
/// `MaterialApp` built with a context above `DynamicLocalization` looks
/// perfectly fine to the analyzer and throws on the first frame.
void main() {
  late Directory tasksDir;

  setUpAll(() async {
    tasksDir = await Directory.systemTemp.createTemp('handoff_boot_');
    final file = File('${tasksDir.path}/acme/api/sample.md');
    await file.parent.create(recursive: true);
    await file.writeAsString(sampleTaskFile);

    // A saved locale wins over the device language, so the assertions below
    // do not depend on the machine running the test.
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    // adaptive_theme reads the mode through the async api, which needs its
    // own in-memory platform in tests.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    locator.initialize(
      external: () {
        locator.registerSingleton<EnvConfig>(
          EnvConfig(
            environment: Environment.dev,
            apiSetupParams: EnvConfigs.dev.apiSetupParams,
            tasksDirectory: tasksDir.path,
          ),
        );
        DependencyConfig.register();
      },
    );
    await locator<Localizor>().initialize();
    locator<RouteManager>().setup(RouteConfig.setupParams);
    locator<ApiManager>().setup(EnvConfigs.dev.apiSetupParams);
  });

  tearDownAll(() => tasksDir.delete(recursive: true));

  testWidgets('boots into the task board and reads the folder', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The task folder is read with real file I/O, which only completes
    // under runAsync; the fake clock of the test would wait forever.
    await tester.runAsync(() async {
      await tester.pumpWidget(_mainApp());
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Rendered through the localizor, so the asset bundle was read.
    expect(find.text('All projects'), findsNWidgets(2));
    expect(find.text('Expected from you'), findsOneWidget);
    // The sample task came off the disk through the whole stack.
    expect(find.text('API için hız sınırı'), findsNWidgets(2));
    expect(find.text('acme/api'), findsWidgets);
  });
}

Widget _mainApp() {
  return MainApp(
    localizor: locator<Localizor>(),
    routeManager: locator<RouteManager>(),
    logger: locator<Logger>(),
    themeMode: ThemeMode.light,
  );
}
