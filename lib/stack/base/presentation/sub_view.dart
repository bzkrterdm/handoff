// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:flutter/material.dart';

import '../../common/extensions/build_context_ext.dart';
import 'controller.dart';

abstract class SubView<TController extends Controller> extends StatelessWidget {
  // Purposely non-const, because updates always should be applied as
  // we may use controller's properties when constructing widgets.
  SubView({super.key});

  /// Describes the widget to be constructed providing the nearest controller.
  @protected
  Widget buildView(BuildContext context, TController controller);

  /// Not to be overridden as controller is not provided.
  @override
  Widget build(BuildContext context) {
    return buildView(context, context.readController<TController>());
  }
}
