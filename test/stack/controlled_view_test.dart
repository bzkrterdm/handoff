import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/stack/base/presentation/controlled_view.dart';
import 'package:handoff/stack/base/presentation/controller.dart';
import 'package:handoff/stack/base/presentation/view_route_observer.dart';
import 'package:handoff/stack/core/ioc/service_locator.dart';

void main() {
  setUpAll(() {
    locator.initialize(
      external: () {
        locator.registerFactory<_TestController>(
          () => _TestController(locator(), locator(), locator(), locator()),
        );
      },
    );
  });

  group('ControlledView visibility', () {
    testWidgets('reports visible on start and hidden once covered', (
      tester,
    ) async {
      final page = _TestPage();
      await tester.pumpWidget(_app(page));
      await tester.pumpAndSettle();

      expect(page.controller.visibilityLog, ['visible']);

      // Cover the page with another route.
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      expect(page.controller.visibilityLog, ['visible', 'hidden']);

      // Uncover it again.
      await tester.tap(find.text('pop'));
      await tester.pumpAndSettle();

      expect(page.controller.visibilityLog, ['visible', 'hidden', 'visible']);
    });
  });

  group('ControlledView back request', () {
    testWidgets('pops and reports didPop when the controller allows', (
      tester,
    ) async {
      final page = _TestPage();
      await tester.pumpWidget(_app(_RootPage(child: page)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('push'), findsOneWidget);

      final didPop = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(didPop, isTrue);
      expect(page.controller.backRequests, [true]);
      expect(find.text('push'), findsNothing);
    });

    testWidgets('blocks the pop when the controller vetoes it', (tester) async {
      final page = _TestPage();
      page.controller.allowBack = false;
      await tester.pumpWidget(_app(_RootPage(child: page)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(page.controller.backRequests, [false]);
      expect(find.text('push'), findsOneWidget);
    });
  });
}

Widget _app(Widget home) {
  return MaterialApp(
    navigatorObservers: [ViewRouteObserver.instance],
    home: home,
  );
}

class _TestController extends Controller<Object> {
  _TestController(
    super.logger,
    super.localizor,
    super.routeManager,
    super.popupManager,
  );

  final List<String> visibilityLog = [];
  final List<bool> backRequests = [];

  bool allowBack = true;

  @override
  bool get canGoBack => allowBack;

  @override
  void onVisible() {
    super.onVisible();
    visibilityLog.add('visible');
  }

  @override
  void onHidden() {
    super.onHidden();
    visibilityLog.add('hidden');
  }

  @override
  Future<void> onBackRequest({required bool didPop}) async {
    await super.onBackRequest(didPop: didPop);
    backRequests.add(didPop);
  }
}

class _TestPage extends ControlledView<_TestController, Object> {
  _TestPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const _OtherPage())),
          child: const Text('push'),
        ),
      ),
    );
  }
}

class _RootPage extends StatelessWidget {
  const _RootPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => child)),
          child: const Text('open'),
        ),
      ),
    );
  }
}

class _OtherPage extends StatelessWidget {
  const _OtherPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('pop'),
        ),
      ),
    );
  }
}
