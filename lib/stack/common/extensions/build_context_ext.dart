import 'package:flutter/widgets.dart';

import '../../base/presentation/controller.dart';
import '../../base/presentation/controller_provider.dart';

extension BuildContextExt on BuildContext {
  /// Helper to get [RouteSettings.arguments] via
  /// `ModalRoute.of(context).settings.arguments`
  Object? get arguments => ModalRoute.of(this)?.settings.arguments;

  /// Obtain the nearest ancestor Controller of type [T].
  T readController<T extends Controller>() {
    return ControllerProvider.of<T>(this);
  }
}
