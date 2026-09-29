import 'package:easy_localization/easy_localization.dart';

/// Wrapper widget to abstract localization.
/// Use this in main to wrap your app widget as below.
///
/// ```dart
/// void main() {
///   runApp(
///     DynamicLocalization(
///       path: 'assets/translations',
///       fallbackLocale: Locale('en', 'US'),
///       supportedLocales: [Locale('en', 'US'), Locale('tr', 'TR')],
///       saveLocale: true,
///       child: YourAppWidget(),
///     ),
///   );
/// }
/// ```
class DynamicLocalization extends EasyLocalization {
  DynamicLocalization({
    super.key,
    required super.child,
    required super.path,
    required super.supportedLocales,
    super.assetLoader,
    super.startLocale,
    super.fallbackLocale,
    super.useFallbackTranslations,
    super.useOnlyLangCode,
    super.saveLocale,
  });
}
