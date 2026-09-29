import '../../stack/common/models/api/api_setup_params.dart';
import 'env_config.dart';

/// The [EnvConfig] of each environment. One entry point per config.
abstract class EnvConfigs {
  static final EnvConfig dev = EnvConfig(
    environment: Environment.dev,
    apiSetupParams: _apiSetupParams('https://dev.example.com/api/'),
    tasksDirectory: _tasksDirectory,
    logProperties: const {'environment': 'dev'},
  );

  static final EnvConfig prod = EnvConfig(
    environment: Environment.prod,
    apiSetupParams: _apiSetupParams('https://example.com/api/'),
    tasksDirectory: _tasksDirectory,
    logProperties: const {'environment': 'prod'},
  );

  // Helpers
  /// The task folder to start with when the user has not picked one yet:
  /// `--dart-define=HANDOFF_TASKS_DIR=/abs/path` (handy for a fixture or the
  /// bundled `example/` workspace), otherwise empty, which makes the app ask
  /// for a workspace folder on first start.
  static String get _tasksDirectory {
    const fromDefine = String.fromEnvironment('HANDOFF_TASKS_DIR');

    return fromDefine;
  }

  /// Shared network setup. Give an environment its own timeouts or headers by
  /// building its [ApiSetupParams] inline instead of calling this.
  static ApiSetupParams _apiSetupParams(String baseUrl) {
    return ApiSetupParams(
      baseUrl: baseUrl,
      baseHeaders: const {'accept': 'application/json'},
      connectTimeout: const Duration(seconds: 30),
      requestTimeout: const Duration(seconds: 30),
      responseTimeout: const Duration(seconds: 30),
      retryCount: 2,
    );
  }

  // - Helpers
}
