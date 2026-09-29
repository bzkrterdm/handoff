import 'package:flutter/foundation.dart';

class ControllerNotFoundException implements Exception {
  const ControllerNotFoundException(this.valueType, this.widgetType);

  /// The type of the value being retrieved
  final Type valueType;

  /// The type of the Widget requesting the value
  final Type widgetType;

  @override
  String toString() {
    if (kReleaseMode) {
      return '$valueType not found for $widgetType';
    }

    return '''
Error: Could not find the correct $valueType above this $widgetType Widget

This happens because you used a `BuildContext` that does not include the Controller
of your choice. There are a few common scenarios:

- If your Widget extends from ControlledView use directly "controller" instead of readController<T>()

- The Controller you are trying to read is in a different route.

  Controllers are "scoped". So if you insert a Controller inside a route, then
  other routes will not be able to access that Controller.

- You used a `BuildContext` that is an ancestor of the Controller you are trying to read.
  ''';
  }
}
