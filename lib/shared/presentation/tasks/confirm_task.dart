import 'package:flutter/material.dart';

import '../../../stack/base/presentation/task.dart';
import '../../../stack/core/localization/translate.dart';

/// Asks the user to confirm something and reports the answer.
///
/// A [Task] is the unit for a presentation step that more than one feature
/// needs: it gets the same dependencies a controller has, and it is executed
/// from a controller with the context of the region it should appear in.
class ConfirmTask extends Task<ConfirmParams, bool> {
  ConfirmTask(
    super.logger,
    super.localizor,
    super.routeManager,
    super.popupManager,
  );

  @override
  Future<bool?> execute(BuildContext context, {ConfirmParams? params}) async {
    if (params == null) return false;

    var isConfirmed = false;
    // showPopup completes when the dialog is gone, so the answer the buttons
    // wrote is readable right after it.
    await popupManager.showPopup(
      context,
      _ConfirmContent(
        params: params,
        onAnswer: (answer) => isConfirmed = answer,
      ),
    );
    logger.info(
      'Confirmation of ${params.messageKey}: $isConfirmed',
      callerType: runtimeType,
    );

    return isConfirmed;
  }
}

/// What to ask, in localization keys.
class ConfirmParams {
  const ConfirmParams({
    required this.messageKey,
    this.confirmKey = 'button_confirm',
    this.cancelKey = 'button_cancel',
  });

  final String messageKey;
  final String confirmKey;
  final String cancelKey;
}

class _ConfirmContent extends StatelessWidget {
  const _ConfirmContent({required this.params, required this.onAnswer});

  final ConfirmParams params;
  final void Function(bool answer) onAnswer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(trt(params.messageKey), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _answer(context, isConfirmed: false),
                  child: Text(trt(params.cancelKey)),
                ),
                FilledButton(
                  onPressed: () => _answer(context, isConfirmed: true),
                  child: Text(trt(params.confirmKey)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helpers
  void _answer(BuildContext context, {required bool isConfirmed}) {
    onAnswer(isConfirmed);
    Navigator.of(context).pop();
  }

  // - Helpers
}
