import 'package:flutter/material.dart';

import '../../../../../configs/localization_config.dart';
import '../../../../../stack/core/localization/translate.dart';
import '../controllers/tasks_controller.dart';

/// The gear in the sidebar: language and appearance, each a sub menu with
/// the current choice ticked.
class SettingsMenu extends StatelessWidget {
  const SettingsMenu({super.key, required this.controller});

  final TasksController controller;

  @override
  Widget build(BuildContext context) {
    final followsDevice = controller.followsDeviceLanguage;
    final locale = controller.currentLocale;
    final themeMode = controller.currentThemeMode;

    return MenuAnchor(
      menuChildren: [
        SubmenuButton(
          leadingIcon: const Icon(Icons.language, size: 18),
          menuChildren: [
            _CheckItem(
              key: const Key('language_system'),
              label: trt('menu_system_default'),
              isChecked: followsDevice,
              onPressed: () => controller.changeLanguage(null),
            ),
            for (final supported in LocalizationConfig.supportedLocales)
              _CheckItem(
                key: Key('language_${supported.languageCode}'),
                label:
                    LocalizationConfig.languageNames[supported.languageCode] ??
                    supported.languageCode,
                isChecked:
                    !followsDevice &&
                    supported.languageCode == locale.languageCode,
                onPressed: () => controller.changeLanguage(supported),
              ),
          ],
          child: Text(trt('menu_language')),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Icons.brightness_6_outlined, size: 18),
          menuChildren: [
            for (final mode in ThemeMode.values)
              _CheckItem(
                key: Key('appearance_${mode.name}'),
                label: trt('menu_appearance_${mode.name}'),
                isChecked: mode == themeMode,
                onPressed: () => controller.changeAppearance(mode),
              ),
          ],
          child: Text(trt('menu_appearance')),
        ),
      ],
      builder: (context, menu, _) => IconButton(
        key: const Key('settings_menu'),
        tooltip: trt('menu_settings'),
        icon: const Icon(Icons.settings_outlined, size: 18),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    super.key,
    required this.label,
    required this.isChecked,
    required this.onPressed,
  });

  final String label;
  final bool isChecked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      leadingIcon: Icon(
        isChecked ? Icons.check : null,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
