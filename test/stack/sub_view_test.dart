import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/stack/base/presentation/controller.dart';
import 'package:handoff/stack/base/presentation/controller_provider.dart';
import 'package:handoff/stack/base/presentation/sub_view.dart';
import 'package:handoff/stack/common/exceptions/controller_not_found_exception.dart';
import 'package:handoff/stack/core/ioc/service_locator.dart';

void main() {
  setUpAll(locator.initialize);

  group('SubView', () {
    testWidgets('finds the nearest controller', (tester) async {
      final controller = _TestController(
        locator(),
        locator(),
        locator(),
        locator(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ControllerProvider<_TestController>(
            controller: controller,
            child: _Region(),
          ),
        ),
      );

      expect(find.text('region of _TestController'), findsOneWidget);
    });

    testWidgets('throws when no controller is above it', (tester) async {
      await tester.pumpWidget(MaterialApp(home: _Region()));

      expect(tester.takeException(), isA<ControllerNotFoundException>());
    });
  });
}

class _TestController extends Controller<Object> {
  _TestController(
    super.logger,
    super.localizor,
    super.routeManager,
    super.popupManager,
  );
}

class _Region extends SubView<_TestController> {
  _Region();

  @override
  Widget buildView(BuildContext context, _TestController controller) {
    return Text('region of ${controller.runtimeType}');
  }
}
