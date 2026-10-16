import 'dart:io';

/// UI language, as in the desktop app: follow the system, or pick one.
enum Language {
  system,
  en,
  tr;

  static Language parse(Object? value) => switch (value) {
    'en' => en,
    'tr' => tr,
    _ => system,
  };
}

/// The interface texts. The keys and wording are the desktop app's
/// (`assets/translations/*.json`), plus what only a terminal needs: key
/// hints and the help screen. The first message to an agent is not here: it
/// is always English (`AgentPrompt` in `handoff_core`).
class Strings {
  Strings(this.code) : _table = code == 'tr' ? _tr : _en;

  /// [language] resolved against the system locale (`LANG`, `LC_ALL`, or
  /// the Windows user locale); English unless that is Turkish.
  factory Strings.of(Language language, {String? systemLocale}) {
    return switch (language) {
      Language.en => Strings('en'),
      Language.tr => Strings('tr'),
      Language.system => Strings(
        _isTurkish(systemLocale ?? _systemLocale()) ? 'tr' : 'en',
      ),
    };
  }

  final String code;
  final Map<String, String> _table;

  /// The text for [key], with `{name}` placeholders filled from [args].
  String call(String key, [Map<String, Object> args = const {}]) {
    var text = _table[key] ?? _en[key] ?? key;
    args.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));

    return text;
  }

  /// Short month names, January first.
  List<String> get months => this('months_short').split(',');

  /// "Show in Finder" / "Show in Explorer" / "Show in folder".
  String get revealLabel => this(
    Platform.isMacOS
        ? 'button_reveal_file'
        : (Platform.isWindows ? 'button_reveal_explorer' : 'button_reveal_dir'),
  );

  // Helpers
  static String _systemLocale() {
    final env = Platform.environment;
    for (final name in ['LC_ALL', 'LC_MESSAGES', 'LANG']) {
      final value = env[name];
      if (value != null && value.isNotEmpty) return value;
    }

    return Platform.localeName;
  }

  static bool _isTurkish(String locale) =>
      locale.toLowerCase().startsWith('tr');

  static const Map<String, String> _en = {
    'title_app': 'Handoff',
    'text_tagline': 'From agents to you',
    'text_projects': 'Projects',
    'text_all_projects': 'All projects',
    'text_open_count_short': '{count} open',
    'text_workspace': 'Workspace folder',
    'button_choose_folder': 'Choose folder',
    'button_refresh': 'Refresh',
    'tab_open': 'Open',
    'tab_done': 'Done',
    'text_no_tasks_open': 'No open tasks',
    'text_no_tasks_open_hint': 'When an agent finishes work, it shows up here.',
    'text_no_tasks_done': 'No done tasks',
    'text_no_tasks_done_hint': 'Tasks you close collect here.',
    'text_select_task': 'Select a task',
    'text_select_task_hint':
        'Pick a task in the list and its details open here.',
    'section_summary': 'Done',
    'section_info': 'Info',
    'section_actions': 'Expected from you',
    'text_no_actions': 'Nothing expected; informational.',
    'text_progress': '{done}/{total} done',
    'text_all_done_hint': 'Everything is ticked — you can close the task.',
    'text_related': 'Related tasks',
    'text_closed_at': 'Closed',
    'button_close_task': 'Mark done',
    'button_reopen': 'Reopen',
    'button_open_file': 'Open file',
    'button_reveal_file': 'Show in Finder',
    'button_reveal_explorer': 'Show in Explorer',
    'button_reveal_dir': 'Show in folder',
    'text_confirm_reopen': 'Reopen this task?',
    'button_confirm': 'Confirm',
    'button_cancel': 'Cancel',
    'text_error_load': 'Could not read the tasks',
    'button_retry': 'Retry',
    'date_today': 'Today',
    'date_yesterday': 'Yesterday',
    'months_short': 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec',
    'button_connect_agent': 'Connect to agent',
    'button_ask_agent_item': 'Ask the agent about this item',
    'menu_settings': 'Settings',
    'menu_language': 'Language',
    'menu_system_default': 'System default',
    'menu_appearance': 'Appearance',
    'menu_appearance_system': 'System',
    'menu_appearance_light': 'Light',
    'menu_appearance_dark': 'Dark',
    'text_welcome': 'Welcome to Handoff',
    'text_welcome_hint':
        'Choose the folder your projects live in. Handoff keeps the tasks '
        'your agents leave in .handoff/tasks inside it.',
    // Terminal only.
    'button_edit_file': 'Edit',
    'button_ask_item': 'Ask agent',
    'button_tick': 'Tick',
    'button_open_workspace': 'Open folder',
    'button_help': 'Help',
    'button_quit': 'Quit',
    'button_back': 'Back',
    'text_loading': 'Reading tasks…',
    'text_too_small': 'Make the window larger',
    'text_keys': 'Keys',
    'text_use_folder': 'Use this folder',
    'text_parent_folder': 'Up one folder',
    'text_has_tasks': 'tasks',
    'text_type_path': 'Type a path, Enter to go there',
    'text_folder_hints':
        '↑↓ move · Enter open · ← up · Tab hidden · / type path · Esc cancel',
    'text_no_subfolders': 'No sub folders',
    'text_agent_missing':
        '"{agent}" is not installed or not on PATH. Install it, then try '
        'again.',
    'text_agent_window': 'Started {agent} in a new tmux window',
    'text_agent_returned': 'Back from {agent}',
    'text_editor_failed': 'Could not start the editor "{editor}"',
    'text_open_failed': 'Could not open {path}',
    'text_choose_hint': 'Press Enter or w to choose a folder',
    'text_retry_hint': 'r retry · w choose another folder · q quit',
    'text_settings_hint': '↑↓ move · Enter choose · Esc close',
    'text_confirm_hint': 'y / Enter confirm · n / Esc cancel',
    'help_move': 'Move',
    'help_panes': 'Switch pane',
    'help_open': 'Open / go in',
    'help_back': 'Back (narrow window), close',
    'help_tick': 'Tick the item under the cursor',
    'help_tick_n': 'Tick item 1–9 from anywhere',
    'help_tab': 'Open ↔ Done list',
    'help_done': 'Mark the task done',
    'help_reopen': 'Reopen the task',
    'help_agent': 'Connect to the task\'s agent',
    'help_ask': 'Ask the agent about the item under the cursor',
    'help_edit': 'Edit the task file in \$EDITOR',
    'help_open_file': 'Open the task file in its app',
    'help_reveal': 'Show the task file in the file manager',
    'help_workspace': 'Choose the workspace folder',
    'help_open_workspace': 'Open the workspace folder',
    'help_refresh': 'Refresh',
    'help_scroll': 'Scroll the details',
    'help_settings': 'Language and appearance',
    'help_quit': 'Quit',
    'help_agent_note':
        'The agent starts in this terminal and Handoff comes back when it '
        'exits (inside tmux: in a new window).',
  };

  static const Map<String, String> _tr = {
    'title_app': 'Handoff',
    'text_tagline': 'Ajanlardan sana',
    'text_projects': 'Projeler',
    'text_all_projects': 'Tüm projeler',
    'text_open_count_short': '{count} açık',
    'text_workspace': 'Çalışma klasörü',
    'button_choose_folder': 'Klasör seç',
    'button_refresh': 'Yenile',
    'tab_open': 'Açık',
    'tab_done': 'Tamamlanan',
    'text_no_tasks_open': 'Açık görev yok',
    'text_no_tasks_open_hint': 'Bir ajan iş bitirdiğinde burada görünür.',
    'text_no_tasks_done': 'Tamamlanan görev yok',
    'text_no_tasks_done_hint': 'Kapattığın görevler burada birikir.',
    'text_select_task': 'Bir görev seç',
    'text_select_task_hint':
        'Listeden bir görev seçince ayrıntısı burada açılır.',
    'section_summary': 'Yapılan',
    'section_info': 'Bilgi',
    'section_actions': 'Senden beklenenler',
    'text_no_actions': 'Beklenen bir şey yok; bilgi amaçlı.',
    'text_progress': '{done}/{total} tamamlandı',
    'text_all_done_hint': 'Tüm maddeler işaretli — görevi kapatabilirsin.',
    'text_related': 'İlgili görevler',
    'text_closed_at': 'Kapatıldı',
    'button_close_task': 'Tamamlandı',
    'button_reopen': 'Yeniden aç',
    'button_open_file': 'Dosyayı aç',
    'button_reveal_file': "Finder'da göster",
    'button_reveal_explorer': "Gezgin'de göster",
    'button_reveal_dir': 'Klasörde göster',
    'text_confirm_reopen': 'Görev yeniden açılsın mı?',
    'button_confirm': 'Onayla',
    'button_cancel': 'Vazgeç',
    'text_error_load': 'Görevler okunamadı',
    'button_retry': 'Tekrar dene',
    'date_today': 'Bugün',
    'date_yesterday': 'Dün',
    'months_short': 'Oca,Şub,Mar,Nis,May,Haz,Tem,Ağu,Eyl,Eki,Kas,Ara',
    'button_connect_agent': 'Agenta bağlan',
    'button_ask_agent_item': 'Bu maddeyi agenta sor',
    'menu_settings': 'Ayarlar',
    'menu_language': 'Dil',
    'menu_system_default': 'Sistem varsayılanı',
    'menu_appearance': 'Görünüm',
    'menu_appearance_system': 'Sistem',
    'menu_appearance_light': 'Açık',
    'menu_appearance_dark': 'Koyu',
    'text_welcome': "Handoff'a hoş geldin",
    'text_welcome_hint':
        'Projelerinin bulunduğu klasörü seç. Handoff, ajanların bıraktığı '
        'görevleri onun içindeki .handoff/tasks klasöründe tutar.',
    'button_edit_file': 'Düzenle',
    'button_ask_item': 'Agenta sor',
    'button_tick': 'İşaretle',
    'button_open_workspace': 'Klasörü aç',
    'button_help': 'Yardım',
    'button_quit': 'Çık',
    'button_back': 'Geri',
    'text_loading': 'Görevler okunuyor…',
    'text_too_small': 'Pencereyi büyüt',
    'text_keys': 'Tuşlar',
    'text_use_folder': 'Bu klasörü kullan',
    'text_parent_folder': 'Üst klasör',
    'text_has_tasks': 'görevler',
    'text_type_path': 'Bir yol yaz, oraya gitmek için Enter',
    'text_folder_hints':
        '↑↓ gez · Enter aç · ← üst · Tab gizli · / yol yaz · Esc vazgeç',
    'text_no_subfolders': 'Alt klasör yok',
    'text_agent_missing':
        '"{agent}" kurulu değil ya da PATH\'te yok. Kurup tekrar dene.',
    'text_agent_window': '{agent} yeni bir tmux penceresinde başladı',
    'text_agent_returned': '{agent} oturumu kapandı',
    'text_editor_failed': '"{editor}" düzenleyicisi başlatılamadı',
    'text_open_failed': '{path} açılamadı',
    'text_choose_hint': 'Klasör seçmek için Enter ya da w',
    'text_retry_hint': 'r tekrar dene · w başka klasör seç · q çık',
    'text_settings_hint': '↑↓ gez · Enter seç · Esc kapat',
    'text_confirm_hint': 'y / Enter onayla · n / Esc vazgeç',
    'help_move': 'Gez',
    'help_panes': 'Sütun değiştir',
    'help_open': 'Aç / içine gir',
    'help_back': 'Geri (dar pencere), kapat',
    'help_tick': 'İmleçteki maddeyi işaretle',
    'help_tick_n': 'Her yerden 1–9. maddeyi işaretle',
    'help_tab': 'Açık ↔ Tamamlanan listesi',
    'help_done': 'Görevi tamamla',
    'help_reopen': 'Görevi yeniden aç',
    'help_agent': 'Görevin ajanına bağlan',
    'help_ask': 'İmleçteki maddeyi ajana sor',
    'help_edit': 'Görev dosyasını \$EDITOR ile düzenle',
    'help_open_file': 'Görev dosyasını kendi uygulamasında aç',
    'help_reveal': 'Görev dosyasını dosya yöneticisinde göster',
    'help_workspace': 'Çalışma klasörünü seç',
    'help_open_workspace': 'Çalışma klasörünü aç',
    'help_refresh': 'Yenile',
    'help_scroll': 'Ayrıntıyı kaydır',
    'help_settings': 'Dil ve görünüm',
    'help_quit': 'Çık',
    'help_agent_note':
        'Ajan bu terminalde başlar, kapanınca Handoff geri gelir (tmux '
        'içindeyken yeni pencerede açılır).',
  };

  // - Helpers
}
