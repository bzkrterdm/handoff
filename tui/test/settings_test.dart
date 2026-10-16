import 'dart:io';

import 'package:handoff_tui/handoff_tui.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('handoff_settings'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('remembers folder, language and appearance across instances', () async {
    final file = File(p.join(dir.path, 'nested', 'tui.json'));
    final settings = TuiSettings(file);
    await settings.setTasksDirectory('/w/.handoff/tasks');
    await settings.setLanguage(Language.tr);
    await settings.setAppearance(Appearance.dark);

    final again = TuiSettings(file);
    expect(await again.tasksDirectory(), '/w/.handoff/tasks');
    expect(again.language, Language.tr);
    expect(again.appearance, Appearance.dark);
  });

  test('"system" removes the stored choice', () async {
    final settings = TuiSettings(File(p.join(dir.path, 'tui.json')));
    await settings.setLanguage(Language.en);
    await settings.setLanguage(Language.system);
    expect(settings.file.readAsStringSync(), isNot(contains('language')));
  });

  test('a broken file means defaults', () async {
    final file = File(p.join(dir.path, 'tui.json'))..writeAsStringSync('{');
    final settings = TuiSettings(file);
    expect(await settings.tasksDirectory(), isNull);
    expect(settings.appearance, Appearance.system);
  });

  test('the standard file follows XDG on macOS and Linux', () {
    if (Platform.isWindows) return;
    expect(
      TuiSettings.standard({'XDG_CONFIG_HOME': '/x'}).file.path,
      '/x/handoff/tui.json',
    );
    expect(
      TuiSettings.standard({'HOME': '/h'}).file.path,
      '/h/.config/handoff/tui.json',
    );
  });

  test('strings follow the system locale unless one is chosen', () {
    expect(Strings.of(Language.system, systemLocale: 'tr_TR.UTF-8').code, 'tr');
    expect(Strings.of(Language.system, systemLocale: 'de_DE').code, 'en');
    expect(Strings.of(Language.en, systemLocale: 'tr_TR').code, 'en');
    expect(
      Strings('tr')('text_progress', {'done': 1, 'total': 3}),
      '1/3 tamamlandı',
    );
  });
}
