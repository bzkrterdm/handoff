import 'package:flutter/material.dart';

/// A tool to show/hide pre-defined or custom popups.
abstract class PopupManager {
  /// Shows a general dialog above the current contents of the app.
  /// [content] specifies the widget to be shown inside the dialog.
  /// [alignment] specifies the alignment of the dialog.
  /// [padding] adds a padding around the dialog.
  /// [barrierColor] specifies the color of the background barrier.
  /// [preventClose] prevents closing the dialog by pressing outside.
  /// [preventBackPress] prevents closing the dialog by pressing back button.
  Future<void> showPopup(
    BuildContext context,
    Widget content, {
    Alignment alignment,
    EdgeInsets padding,
    Color? barrierColor,
    bool preventClose,
    bool preventBackPress,
  });

  /// Shows a full screen dialog above the current contents of the app.
  /// [content] specifies the widget to be shown inside the dialog.
  /// [preventBackPress] prevents closing the dialog by pressing back button.
  Future<void> showFullScreenPopup(
    BuildContext context,
    Widget content, {
    bool preventBackPress,
  });

  /// Shows a bottom sheet dialog above the current contents of the app.
  /// [content] specifies the widget to be shown inside the dialog.
  /// [width] specifies the width of the dialog.
  /// [height] specifies the height of the dialog.
  /// [borderRadius] specifies the border radius of the dialog.
  /// [barrierColor] specifies the color of the background barrier.
  /// [preventClose] prevents closing the dialog by pressing outside.
  /// [preventBackPress] prevents closing the dialog by pressing back button.
  /// [enableDrag] enables dragging functionality of the dialog.
  Future<void> showBottomPopup(
    BuildContext context,
    Widget content, {
    double width,
    double height,
    double borderRadius,
    Color? barrierColor,
    bool preventClose,
    bool preventBackPress,
    bool enableDrag,
  });

  /// Shows a sliding bottom sheet dialog above the current contents of the app.
  /// [content] specifies the widget to be shown inside the dialog.
  /// [width] specifies the width of the dialog.
  /// [initialHeightSnap] specifies the initial height snap of the dialog.
  /// [heightSnaps] specifies height snaps that the dialog can be dragged to.
  /// [borderRadius] specifies the border radius of the dialog.
  /// [barrierColor] specifies the color of the background barrier.
  /// [elevation] specifies the elevation of the dialog.
  /// [dragIndicatorColor] specifies the color of the optional drag indicator
  /// on top of the dialog.
  /// [preventClose] prevents closing the dialog by pressing outside.
  /// [preventBackPress] prevents closing the dialog by pressing back button.
  /// [controller] drives the sheet programmatically.
  ///
  /// [content] is laid out inside the sheet's own scroll view, so it must size
  /// itself vertically — do not pass an unbounded list. When the sheet content
  /// *is* a list, pass [contentBuilder] instead and hand the given
  /// [ScrollController] to that list, which is what lets dragging the list
  /// drag the sheet.
  Future<void> showSlidingBottomPopup(
    BuildContext context,
    Widget content, {
    double width,
    double? initialHeightSnap,
    List<double> heightSnaps,
    double borderRadius,
    Color? barrierColor,
    double elevation,
    Color? dragIndicatorColor,
    bool preventClose,
    bool preventBackPress,
    CustomSheetController? controller,
    Widget Function(ScrollController scrollController)? contentBuilder,
  });
}

class PopupManagerImpl implements PopupManager {
  /// Smallest snap a sheet can be given, so that a stray 0 height does not
  /// produce an invisible sheet.
  static const double _minSnapFraction = 0.05;

  @override
  Future<void> showPopup(
    BuildContext context,
    Widget content, {
    Alignment alignment = Alignment.center,
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 20,
    ),
    Color? barrierColor,
    bool preventClose = false,
    bool preventBackPress = false,
  }) {
    return _showGeneralDialog(
      context,
      content,
      alignment: alignment,
      padding: padding,
      preventClose: preventClose,
      preventBackPress: preventBackPress,
      barrierColor: barrierColor,
      showFullScreen: false,
    );
  }

  @override
  Future<void> showFullScreenPopup(
    BuildContext context,
    Widget content, {
    bool preventBackPress = false,
  }) {
    return _showGeneralDialog(
      context,
      content,
      preventBackPress: preventBackPress,
      showFullScreen: true,
      enableSlideAnimation: true,
    );
  }

  @override
  Future<void> showBottomPopup(
    BuildContext context,
    Widget content, {
    double width = double.infinity,
    double height = double.infinity,
    double borderRadius = 0,
    Color? barrierColor,
    bool preventClose = false,
    bool preventBackPress = false,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet(
      context: context,
      enableDrag: enableDrag,
      isScrollControlled: enableDrag,
      isDismissible: !preventClose,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      barrierColor: barrierColor ?? Colors.black26,
      constraints: BoxConstraints(maxWidth: width, maxHeight: height),
      builder: (_) {
        return SafeArea(
          child: PopScope(canPop: !preventBackPress, child: content),
        );
      },
    );
  }

  @override
  Future<void> showSlidingBottomPopup(
    BuildContext context,
    Widget content, {
    double width = double.infinity,
    double? initialHeightSnap,
    List<double> heightSnaps = const [double.infinity],
    double borderRadius = 25,
    Color? barrierColor,
    double elevation = 16,
    Color? dragIndicatorColor,
    bool preventClose = false,
    bool preventBackPress = false,
    CustomSheetController? controller,
    Widget Function(ScrollController scrollController)? contentBuilder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: !preventClose,
      enableDrag: !preventClose,
      backgroundColor: Colors.transparent,
      barrierColor: barrierColor ?? Colors.black26,
      constraints: BoxConstraints(maxWidth: width),
      builder: (sheetContext) {
        final snaps = _resolveSnaps(
          sheetContext,
          heightSnaps: heightSnaps,
          initialHeightSnap: initialHeightSnap,
        );

        return SafeArea(
          top: false,
          child: PopScope(
            canPop: !preventBackPress,
            child: DraggableScrollableSheet(
              controller: controller?._sheetController,
              initialChildSize: snaps.initial,
              minChildSize: snaps.min,
              maxChildSize: snaps.max,
              snap: true,
              snapSizes: snaps.intermediates,
              shouldCloseOnMinExtent: !preventClose,
              expand: false,
              builder: (_, scrollController) {
                return _buildSheetSurface(
                  sheetContext,
                  content,
                  scrollController: scrollController,
                  contentBuilder: contentBuilder,
                  borderRadius: borderRadius,
                  elevation: elevation,
                  dragIndicatorColor: dragIndicatorColor,
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Helpers
  /// Converts the logical pixel heights of the public API into the fractions
  /// [DraggableScrollableSheet] works with. `double.infinity` means fullscreen.
  _SheetSnaps _resolveSnaps(
    BuildContext context, {
    required List<double> heightSnaps,
    required double? initialHeightSnap,
  }) {
    // The sheet is laid out against the full screen height, which is what
    // the fractions below are relative to.
    final screenHeight = MediaQuery.sizeOf(context).height;
    double toFraction(double height) =>
        (height / screenHeight).clamp(_minSnapFraction, 1);

    final fractions = heightSnaps.isEmpty
        ? const [1.0]
        : (heightSnaps.map(toFraction).toSet().toList()..sort());
    final min = fractions.first;
    final max = fractions.last;

    return _SheetSnaps(
      min: min,
      max: max,
      initial: initialHeightSnap != null
          ? toFraction(initialHeightSnap).clamp(min, max)
          : max,
      intermediates: fractions
          .where((fraction) => fraction > min && fraction < max)
          .toList(),
    );
  }

  /// The visible sheet: rounded surface, drag indicator and the content.
  ///
  /// [scrollController] must end up on a scrollable, otherwise the sheet
  /// cannot be dragged and [CustomSheetController] never attaches. Without a
  /// [contentBuilder] the sheet provides that scrollable itself.
  Widget _buildSheetSurface(
    BuildContext context,
    Widget content, {
    required ScrollController scrollController,
    required Widget Function(ScrollController)? contentBuilder,
    required double borderRadius,
    required double elevation,
    required Color? dragIndicatorColor,
  }) {
    final dragIndicator = _buildDragIndicator(context, dragIndicatorColor);

    return Material(
      elevation: elevation,
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
      child: contentBuilder != null
          ? Column(
              children: [
                dragIndicator,
                Expanded(child: contentBuilder(scrollController)),
              ],
            )
          : CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(child: dragIndicator),
                SliverFillRemaining(hasScrollBody: false, child: content),
              ],
            ),
    );
  }

  Widget _buildDragIndicator(BuildContext context, Color? color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        child: Container(
          width: 50,
          height: 4,
          decoration: BoxDecoration(
            color: color ?? Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
    );
  }

  Future<void> _showGeneralDialog(
    BuildContext context,
    Widget content, {
    Alignment? alignment,
    EdgeInsets? padding,
    bool? preventClose,
    Color? barrierColor,
    required bool preventBackPress,
    required bool showFullScreen,
    bool enableSlideAnimation = false,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: preventClose != null ? !preventClose : true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor ?? Colors.black26,
      transitionBuilder: enableSlideAnimation
          ? (_, anim1, _, child) {
              return SlideTransition(
                position: Tween(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(anim1),
                child: child,
              );
            }
          : null,
      pageBuilder: (_, _, _) {
        return SafeArea(
          left: !showFullScreen,
          top: !showFullScreen,
          right: !showFullScreen,
          bottom: !showFullScreen,
          child: PopScope(
            canPop: !preventBackPress,
            child: Align(
              alignment: alignment ?? Alignment.center,
              child: Padding(
                padding: showFullScreen
                    ? EdgeInsets.zero
                    : padding ?? EdgeInsets.zero,
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }

  // - Helpers
}

/// Drives a sliding bottom popup from outside its own subtree.
class CustomSheetController {
  CustomSheetController();

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  /// Animates the sheet to its largest snap.
  void expand() {
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Animates the sheet to its smallest snap.
  void collapse() {
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void dispose() {
    _sheetController.dispose();
  }
}

/// Height snaps of a sliding bottom popup, as fractions of the screen height.
class _SheetSnaps {
  const _SheetSnaps({
    required this.min,
    required this.max,
    required this.initial,
    required this.intermediates,
  });

  final double min;
  final double max;
  final double initial;

  /// Snaps strictly between [min] and [max], which is what
  /// [DraggableScrollableSheet.snapSizes] accepts.
  final List<double> intermediates;
}
