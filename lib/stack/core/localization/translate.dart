// ignore_for_file: prefer-static-class

import '../ioc/service_locator.dart';
import 'localizor.dart';

/// Translates [key] from anywhere a [Localizor] instance is not at hand —
/// typically inside widgets, where the alternative is passing the localizor
/// down the tree. Controllers should use their own `localizor` field instead.
///
/// ```dart
/// Text(trt('text_hello_name', namedArgs: {'name': 'Ada'}))
/// ```
String trt(
  String key, {
  num? pluralValue,
  List<String>? args,
  Map<String, String>? namedArgs,
}) {
  return locator<Localizor>().tr(
    key,
    pluralValue: pluralValue,
    args: args,
    namedArgs: namedArgs,
  );
}
