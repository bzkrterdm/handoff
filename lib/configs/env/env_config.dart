import '../../stack/common/models/api/api_setup_params.dart';
import '../../stack/core/logging/log_sink.dart';

/// Everything that differs between environments, resolved at compile time by
/// the entry point that starts the app (`lib/main_dev.dart` and friends).
///
/// It is registered in the service locator by `mainBase`, so app code reads it
/// with `locator<EnvConfig>()` instead of reaching for a global.
class EnvConfig {
  const EnvConfig({
    required this.environment,
    required this.apiSetupParams,
    required this.tasksDirectory,
    this.logSinks = const [],
    this.logProperties = const {},
  });

  /// Which environment this build is.
  final Environment environment;

  /// Network setup handed to `ApiManager.setup`. Unused while the task store
  /// is local; kept so the Supabase data source can be wired without touching
  /// the bootstrap.
  final ApiSetupParams apiSetupParams;

  /// Absolute path of the task folder to use until the user picks one in the
  /// app (`<workspace>/.handoff/tasks`). Empty means "ask on first start".
  ///
  /// Resolved by [EnvConfigs] from `--dart-define=HANDOFF_TASKS_DIR`.
  final String tasksDirectory;

  /// Remote log destinations handed to `Logger.initialize`. Empty means the
  /// console only.
  final List<LogSink> logSinks;

  /// Properties attached to every log record, e.g. the environment name.
  final Map<String, Object> logProperties;
}

/// The environments the app is built for. Add one here, give it a config in
/// `EnvConfigs` and an entry point under `lib/`.
enum Environment {
  dev,
  prod;

  bool get isDev => this == Environment.dev;

  bool get isProd => this == Environment.prod;
}
