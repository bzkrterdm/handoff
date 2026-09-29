import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/stack/core/popup/popup_manager.dart';

void main() {
  group('PopupManagerImpl.showSlidingBottomPopup', () {
    testWidgets('opens at the initial snap and expands to the largest', (
      tester,
    ) async {
      final controller = CustomSheetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller: controller));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('sheet content'), findsOneWidget);
      // 200 of the 600pt tall test surface.
      expect(_sheetHeight(tester), moreOrLessEquals(200, epsilon: 1));

      controller.expand();
      await tester.pumpAndSettle();

      // Clamped to the largest snap, 400, not to the full screen.
      expect(_sheetHeight(tester), moreOrLessEquals(400, epsilon: 1));
    });

    testWidgets('lets a list content drive the sheet', (tester) async {
      final controller = CustomSheetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          controller: controller,
          contentBuilder: (scrollController) => ListView(
            controller: scrollController,
            children: const [Text('sheet content')],
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('sheet content'), findsOneWidget);

      controller.expand();
      await tester.pumpAndSettle();

      expect(_sheetHeight(tester), moreOrLessEquals(400, epsilon: 1));
    });

    testWidgets('keeps the sheet open when closing is prevented', (
      tester,
    ) async {
      await tester.pumpWidget(_host(preventClose: true));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('sheet content'), findsOneWidget);

      // Tapping the barrier must not dismiss it.
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();

      expect(find.text('sheet content'), findsOneWidget);
    });
  });
}

double _sheetHeight(WidgetTester tester) {
  return tester
      .getSize(
        find.descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.byType(Material),
        ),
      )
      .height;
}

Widget _host({
  CustomSheetController? controller,
  bool preventClose = false,
  Widget Function(ScrollController)? contentBuilder,
}) {
  final popupManager = PopupManagerImpl();

  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return Center(
            child: TextButton(
              onPressed: () => popupManager.showSlidingBottomPopup(
                context,
                const Text('sheet content'),
                initialHeightSnap: 200,
                heightSnaps: const [200, 400],
                preventClose: preventClose,
                controller: controller,
                contentBuilder: contentBuilder,
              ),
              child: const Text('open'),
            ),
          );
        },
      ),
    ),
  );
}
