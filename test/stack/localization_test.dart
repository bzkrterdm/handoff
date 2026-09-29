import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/configs/localization_config.dart';
import 'package:handoff/stack/core/ioc/service_locator.dart';
import 'package:handoff/stack/core/localization/dynamic_localization.dart';
import 'package:handoff/stack/core/localization/localizor.dart';
import 'package:handoff/stack/core/localization/translate.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Checks that the configured asset path and locale actually resolve — the
/// mistake this catches is a translation file named for a locale nobody asked
/// for, which only shows up as untranslated text at runtime.
///
/// Everything lives in one widget tree on purpose: a second
/// [DynamicLocalization] in the same isolate never renders its child.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    locator.initialize();
    await locator<Localizor>().initialize();
  });

  testWidgets('resolves keys from the configured assets', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Translated through the widget helper and through the controller API.
    expect(find.text('Tüm projeler'), findsOneWidget);
    expect(find.text('Handoff'), findsOneWidget);
    // A missing key renders as itself instead of throwing or rendering empty.
    expect(find.text('text_not_translated'), findsOneWidget);
  });
}

Widget _app() {
  return DynamicLocalization(
    path: LocalizationConfig.assetsPath,
    supportedLocales: LocalizationConfig.supportedLocales,
    // Turkish explicitly, to prove the secondary file resolves too.
    startLocale: const Locale('tr'),
    fallbackLocale: LocalizationConfig.fallbackLocale,
    useFallbackTranslations: true,
    useOnlyLangCode: LocalizationConfig.useOnlyLangCode,
    child: Builder(
      builder: (context) {
        final localizor = locator<Localizor>();

        return MaterialApp(
          localizationsDelegates: localizor.getLocalizationDelegates(context),
          supportedLocales: localizor.getSupportedLocales(context),
          locale: localizor.getLocale(context),
          home: Column(
            children: [
              Text(trt('text_all_projects')),
              Text(localizor.tr('title_app')),
              Text(trt('text_not_translated')),
            ],
          ),
        );
      },
    ),
  );
}
