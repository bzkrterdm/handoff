import 'dependency_imports.dart';

/// App level registrations, handed to `locator.initialize(external: ...)`.
///
/// The stack registers its own core services (logger, api manager, route
/// manager etc.). Everything a feature owns is registered here, in
/// data -> domain -> presentation order.
///
/// Rule of thumb: `registerLazySingleton` for repositories, remote services
/// and anything worth caching; `registerFactory` for controllers, cubits and
/// use cases, so every page opens with a fresh instance.
abstract class DependencyConfig {
  static void register() {
    _registerData();
    _registerDomain();
    _registerPresentation();
  }

  // Helpers
  /// Local storages, remote services and repository implementations.
  ///
  /// The task store is chosen here and nowhere else: to move to Supabase,
  /// register a `SupabaseTaskDataSource` as [TaskDataSource] instead of the
  /// markdown one. The repository, use cases and UI stay as they are.
  static void _registerData() {
    locator
      ..registerLazySingleton<WorkspaceSettings>(WorkspaceSettingsImpl.new)
      ..registerLazySingleton<TaskDataSource>(
        () => MarkdownTaskDataSource(
          locator(),
          locator<EnvConfig>().tasksDirectory,
          locator(),
        ),
      )
      ..registerLazySingleton<TaskRepository>(
        () => TaskRepositoryImpl(locator()),
      )
      ..registerLazySingleton<ExternalOpener>(
        () => ExternalOpenerImpl(locator()),
      )
      ..registerLazySingleton<FolderPicker>(FolderPickerImpl.new)
      ..registerLazySingleton<DockBadge>(() => DockBadgeImpl(locator()))
      ..registerLazySingleton<AgentLauncher>(
        () => AgentLauncherImpl(locator()),
      );
  }

  /// Use cases.
  static void _registerDomain() {
    locator
      ..registerFactory<WatchTasks>(() => WatchTasks(locator(), locator()))
      ..registerFactory<SetActionDone>(
        () => SetActionDone(locator(), locator()),
      )
      ..registerFactory<SetTaskStatus>(
        () => SetTaskStatus(locator(), locator()),
      )
      ..registerFactory<SetWorkspace>(() => SetWorkspace(locator(), locator()));
  }

  /// Tasks, cubits and controllers.
  static void _registerPresentation() {
    locator
      ..registerFactory<ConfirmTask>(
        () => ConfirmTask(locator(), locator(), locator(), locator()),
      )
      ..registerFactory<TasksCubit>(
        () => TasksCubit(locator(), locator(), locator(), locator()),
      )
      ..registerFactory<TasksController>(
        () => TasksController(
          locator(),
          locator(),
          locator(),
          locator(),
          locator(),
          locator(),
          locator(),
          locator(),
          locator(),
          locator(),
        ),
      );
  }

  // - Helpers
}
