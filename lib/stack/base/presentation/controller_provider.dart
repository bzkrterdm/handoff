import 'package:flutter/material.dart';

import '../../common/exceptions/controller_not_found_exception.dart';
import 'controller.dart';

class ControllerProvider<T extends Controller> extends InheritedWidget {
  const ControllerProvider({
    required this.controller,
    required super.child,
    super.key,
  });

  final T controller;

  @override
  bool updateShouldNotify(covariant ControllerProvider<T> oldWidget) {
    return false;
  }

  static T of<T extends Controller>(BuildContext context) {
    final value = context
        .getInheritedWidgetOfExactType<ControllerProvider<T>>();

    if (value == null) {
      throw ControllerNotFoundException(T, context.widget.runtimeType);
    }
    return value.controller;
  }
}
