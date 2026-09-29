# Handoff — Agent Rules

These are the working rules for this repository, for any coding agent and for
people. `CLAUDE.md` points here; keep this the single copy so the two cannot
drift apart.

Handoff is a macOS app with one feature, `tasks`, on top of a small
clean-architecture stack in `lib/stack/` (base classes, data layer, DI,
routing, theming, localization). Most of the stack is the way it is on
purpose; treat a change there as a design change, not a cleanup. The app's
structure is in [docs/architecture.md](docs/architecture.md); the
maintainers' decision log and progress notes are private and kept outside
this repository.

## 🚨 Critical rules

### 0. Do not build the app — verify with `flutter analyze` and `flutter test`

Builds take minutes, occupy the machine, and tell you almost nothing static
analysis does not.

❌ Never run: `flutter build`, `flutter run`, `xcodebuild`, `gradlew`,
`pod install`.

✅ Verify with:

```bash
flutter analyze     # must be clean — this is the bar
flutter test        # when logic changed
dart format .       # formatting
```

If a change genuinely cannot be validated without a build (native
plist/entitlement edits, a new plugin with native code), say so and let the
developer run it.

### 1. Separation of concerns

**Widgets are dumb. Controllers are smart. Data sources are focused.**

❌ Never in widgets: api calls, repository or use case calls, database access,
business logic, data transformation, direct state mutation.
✅ Widgets only: display state, forward input to the controller, show
loading/error states.
✅ Controllers: presentation logic, orchestrating cubits, navigation, popups.
✅ Data layer: http, storage, serialization, caching.

### 2. Layer rules (enforced twice)

- `domain/` — no Flutter imports, no `data/` or `presentation/` imports.
- `presentation/` — no `data/` imports; depend on domain interfaces.
- `data/` — no `presentation/` imports.

`test/architecture_test.dart` fails the build on a violation, and
`dart run dart_code_linter:metrics analyze lib` (`avoid-banned-imports`)
reports it as well. Never weaken either one to make an import work.

### 3. Pages and controllers

- Every page extends `ControlledView<TController, TParams>`.
- Every controller extends `Controller<TParams>` with the four positional
  dependencies: `logger`, `localizor`, `routeManager`, `popupManager`.
- Every cubit extends `SafeCubit<TState>`; add `UseCaseCancelMixin` when it
  runs use cases, and cancel them in `close()`.
- States are sealed classes with `Initial` / `Loading` / `Success` / `Error`
  variants, matched exhaustively in the view.
- `context.read<T>()` in event handlers, `BlocBuilder`/`BlocConsumer` for
  rebuilds. Never `context.watch<T>()` in a handler.
- First data load belongs in the controller's `onReady()`, not in `build()`.

### 4. Back handling and visibility

- Veto a back gesture with `Controller.canGoBack` (synchronous — read by
  `PopScope`). Anything async, including a confirmation dialog, goes in
  `onBackRequest({required bool didPop})`, which receives `didPop: false` when
  the veto blocked the pop.
- `onVisible`/`onHidden` need `ViewRouteObserver.instance` in
  `MaterialApp.navigatorObservers` — already wired in `main_base.dart`.

### 5. Async safety

- Check `mounted` (or `controller.isActive`) before using `context` after an
  `await`, or capture what you need before it.
- Use `WidgetsBinding.instance.addPostFrameCallback` for work that needs the
  first frame.

### 6. Style (all lint enforced)

- 80 character lines, single quotes, trailing commas.
- Imports: Dart SDK, Flutter SDK, third party, project — alphabetical inside
  each group, relative imports within `lib/`.
- Static fields before instance fields; constructors first.
- Private helpers at the end of the class between `// Helpers` and
  `// - Helpers`.

## 📂 Structure

```
lib/
├── configs/          # App configuration: env, routes, localization, DI
├── features/         # Feature modules (data / domain / presentation)
├── shared/           # Cross-feature app code
├── stack/            # The reusable framework — base / common / core
├── main_base.dart    # mainBase(EnvConfig): locator -> l10n -> routes -> api
├── main_dev.dart     # Entry point per environment
└── main_prod.dart
```

There is no `lib/main.dart`: run an entry point (`flutter run -t
lib/main_dev.dart`) so a build cannot pick the wrong backend.

| Need | File |
|------|------|
| DI registrations | `lib/configs/dependency/dependency_config.dart` + `dependency_imports.dart` |
| Routes | `lib/configs/route_config.dart` |
| Environments | `lib/configs/env/env_config.dart` + `env_configs.dart` |
| Service locator | `lib/stack/core/ioc/service_locator.dart` |
| Controller / ControlledView | `lib/stack/base/presentation/` |
| UseCase | `lib/stack/base/domain/use_case.dart` |
| Result / Failure | `lib/stack/common/models/` |
| Api models | `lib/stack/common/models/api/` |
| Translations | `assets/translations/en.json` |
| Lint rules | `analysis_options.yaml` |

## 🎯 Patterns

### Result

`Result<TValue, TError>` is sealed: `Success` and `Failed`. Prefer matching
over null checks; `isSuccessful` / `value` / `error` exist for the short path.

```dart
switch (result) {
  case Success(:final value?):
    emit(UsersSuccess(users: value));
  case Success():
    emit(const UsersSuccess(users: []));
  case Failed(:final error):
    emit(UsersError(message: error.message));
}
```

`ApiError extends Failure`, so a data layer can return it straight through.
`ApiResult<T>` is a `typedef` for `Result<T, ApiError>`, not a subclass.

### Adding a feature

Write it in dependency order, copying `lib/features/example/`:

1. `domain/entities/*.dart` — `extends Equatable`, no Flutter.
2. `domain/repositories/*_repository.dart` — returns `Result<T, Failure>`.
3. `domain/use_cases/*.dart` — `extends UseCase<TInput, TOutput, TEvent>`.
4. `data/models/*_model.dart` — `@JsonSerializable` + `toEntity()`, then
   `dart run build_runner build --delete-conflicting-outputs`.
5. `data/data_sources/remote/apis/*_api.dart` — `static ApiCall<T>` factories.
6. `data/data_sources/remote/services/*_remote_service.dart` — interface and
   impl in one file, calling `_apiManager.call(...)`.
7. `data/repositories/*_repository_impl.dart` — map models to entities, let no
   exception escape.
8. `presentation/blocs/*_cubit.dart` (+ `*_state.dart` as a `part`).
9. `presentation/ui/controllers/*_controller.dart`.
10. `presentation/ui/pages/*_page.dart`.
11. **Register in DI** — export from `dependency_imports.dart` (alphabetically)
    and register in the matching `_register*` method. Forgetting this is the
    `Bad state: GetIt: Object/factory with type X not registered` error.
12. **Add the route** — a `static const` name, a `RouteDefinition`, and the
    definition listed in `setupParams`. A feature scoped cubit is provided by
    the route so it closes with the page.

`registerLazySingleton` for repositories, remote services and managers;
`registerFactory` for controllers, cubits and use cases.
`registerOverride` replaces a core default (e.g. the analytics vendor).

### Localization

Add the key to `assets/translations/en.json`. `trt('key')` in widgets,
`localizor.tr('key')` in controllers. Files are named by language code
(`en.json`) — see `LocalizationConfig.useOnlyLangCode`.

### Telemetry and security

The stack ships no telemetry vendor. Crash/trace reporting is a `LogSink`
given to `EnvConfig.logSinks` (none is wired today); product analytics is an
`AnalyticsService` registered with `locator.registerOverride`. Do not add a vendor SDK to the stack itself.

`SecurityChecker` (freeRASP) runs only when `EnvConfig.securitySetupParams` is
set. Leave it null for development environments, and never enable it with
placeholder package names or certificate hashes — it will fire on a legitimate
install.

### Storage

`LocalStorage<T>` is an encrypted `hive_ce` box per type, values stored as
JSON. Two subclasses with the same value type must override `boxName`, or they
share one box and clearing either wipes both. Register the model's `fromJson`
as a factory param so the base class can deserialize:

```dart
locator.registerFactoryParam<Foo, Map<String, dynamic>, void>(
  (json, _) => Foo.fromJson(json),
);
```

## 🧪 Testing

`test/` mirrors `lib/`. Four patterns, all in the repo already:

- Repository — `mocktail` mock of the remote service.
- Cubit — `blocTest` with a mocked repository behind a real use case.
- Page — `MockCubit` plus `Localizor` overridden to echo keys, so no
  translation assets are needed.
- Architecture — `test/architecture_test.dart` for the layer rules.

Use `tester.pump()` rather than `pumpAndSettle()` when a progress indicator is
on screen; it never settles. Only one `EasyLocalization` (so one `MainApp` or
`DynamicLocalization`) can render per test file — a second instance in the same
isolate never builds its child, so put those assertions in one widget tree.

`test/main_base_test.dart` boots the whole app. Anything that changes DI,
routing, localization or the `MainApp` tree has to keep it green: that class of
mistake is invisible to the analyzer and to unit tests.

## ⚠️ Anti-patterns

- Api/repository/use case calls in `build()` or a widget callback.
- Flutter imports in `domain/`, `data/` imports in `presentation/`.
- Raw `Cubit` instead of `SafeCubit`.
- A page as a bare `StatelessWidget`/`StatefulWidget` instead of
  `ControlledView`.
- Reaching for a global instead of the locator (`EnvConfig` included).
- Adding a dependency to replace something Flutter already does.
