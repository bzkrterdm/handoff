import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/features/tasks/domain/entities/task_action.dart';
import 'package:handoff/features/tasks/domain/entities/task_status.dart';
import 'package:handoff/features/tasks/presentation/blocs/tasks_cubit.dart';
import 'package:handoff/features/tasks/presentation/ui/controllers/tasks_controller.dart';
import 'package:handoff/features/tasks/presentation/ui/pages/tasks_page.dart';
import 'package:handoff/features/tasks/presentation/ui/widgets/project_column.dart';
import 'package:handoff/shared/domain/agent_launcher.dart';
import 'package:handoff/shared/domain/dock_badge.dart';
import 'package:handoff/shared/domain/external_opener.dart';
import 'package:handoff/shared/domain/folder_picker.dart';
import 'package:handoff/shared/presentation/tasks/confirm_task.dart';
import 'package:handoff/stack/base/presentation/view_route_observer.dart';
import 'package:handoff/stack/core/ioc/service_locator.dart';
import 'package:handoff/stack/core/localization/localizor.dart';
import 'package:handoff/stack/core/theme/theme_manager.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../fixtures/task_fixtures.dart';

/// The page test pattern: mock the cubit, drive states into it, and assert on
/// what the page renders and on what it asks its controller to do.
void main() {
  late MockExternalOpener opener;
  late MockFolderPicker picker;
  late MockDockBadge badge;
  late MockAgentLauncher launcher;
  late MockThemeManager themes;
  late _EchoLocalizor localizor;

  final open = task(
    id: 'f1',
    project: 'acme/web',
    title: 'Flutter PR',
    actions: const [
      TaskAction(text: 'merge'),
      TaskAction(text: 'test', isDone: true),
    ],
  );
  final done = task(
    id: 'd1',
    project: 'acme/web',
    title: 'Old one',
    status: TaskStatus.done,
  );

  setUpAll(() {
    registerFallbackValue(TaskStatus.open);
    opener = MockExternalOpener();
    picker = MockFolderPicker();
    badge = MockDockBadge();
    launcher = MockAgentLauncher();
    themes = MockThemeManager();
    localizor = _EchoLocalizor();
    registerFallbackValue(ThemeMode.system);
    registerFallbackValue(_FakeContext());
    registerFallbackValue(
      const AgentLaunch(agent: '', workingDirectory: '', prompt: ''),
    );
    locator.initialize(
      external: () {
        locator
          ..registerOverride<Localizor>(() => localizor)
          ..registerOverride<ThemeManager>(() => themes)
          ..registerLazySingleton<ExternalOpener>(() => opener)
          ..registerLazySingleton<FolderPicker>(() => picker)
          ..registerLazySingleton<DockBadge>(() => badge)
          ..registerLazySingleton<AgentLauncher>(() => launcher)
          ..registerFactory<ConfirmTask>(
            () => ConfirmTask(locator(), locator(), locator(), locator()),
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
      },
    );
  });

  setUp(() {
    // A desktop sized surface: the three columns do not fit 800x600.
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
    when(() => opener.open(any())).thenAnswer((_) async {});
    when(() => opener.reveal(any())).thenAnswer((_) async {});
    when(() => badge.setCount(any())).thenAnswer((_) async {});
    when(() => launcher.launch(any())).thenAnswer((_) async {});
    when(() => themes.currentThemeMode(any())).thenReturn(ThemeMode.system);
    when(() => themes.changeThemeMode(any(), any())).thenReturn(null);
    when(
      () => picker.pick(
        initialDirectory: any(named: 'initialDirectory'),
        title: any(named: 'title'),
      ),
    ).thenAnswer((_) async => '/picked');
  });

  testWidgets('starts the cubit and shows a spinner', (tester) async {
    final cubit = _mockCubit(const TasksInitial());

    await tester.pumpWidget(_app(cubit));
    await tester.pump();

    verify(cubit.start).called(1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders projects, the list and the selected task', (
    tester,
  ) async {
    final cubit = _mockCubit(
      TasksLoaded(tasks: [open, done], selectedTaskId: 'f1'),
    );

    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    // "All projects" appears as the sidebar row and as the list heading.
    expect(find.text('text_all_projects'), findsNWidgets(2));
    expect(find.text('acme/web'), findsWidgets);
    // Title in the list and in the detail column.
    expect(find.text('Flutter PR'), findsNWidgets(2));
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('merge'), findsOneWidget);
    expect(find.byKey(const Key('close_task')), findsOneWidget);
    // The done task is not in the open list.
    expect(find.text('Old one'), findsNothing);
  });

  testWidgets('keeps the Dock badge at the open count', (tester) async {
    final cubit = MockTasksCubit();
    whenListen(
      cubit,
      Stream.fromIterable([
        TasksLoaded(tasks: [open, done], selectedTaskId: 'f1'),
        const TasksError(message: 'gone'),
      ]),
      initialState: const TasksLoading(),
    );
    when(cubit.start).thenAnswer((_) async {});

    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    verifyInOrder([() => badge.setCount(1), () => badge.setCount(0)]);
  });

  testWidgets('forwards taps to the cubit', (tester) async {
    final cubit = _mockCubit(
      TasksLoaded(tasks: [open, done], selectedTaskId: 'f1'),
    );

    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(ProjectColumn),
        matching: find.text('acme/web'),
      ),
    );
    verify(() => cubit.selectProject('acme/web')).called(1);

    await tester.tap(find.byType(Checkbox).first);
    verify(
      () => cubit.setActionDone(taskId: 'f1', index: 0, isDone: true),
    ).called(1);

    await tester.tap(find.byKey(const Key('close_task')));
    verify(
      () => cubit.setStatus(taskId: 'f1', status: TaskStatus.done),
    ).called(1);

    await tester.tap(find.text('tab_done'));
    verify(() => cubit.showDone(showDone: true)).called(1);

    await tester.tap(find.text('button_open_file'));
    await tester.pump();
    verify(() => opener.open(open.location!)).called(1);

    await tester.tap(find.byKey(const Key('pick_workspace')));
    await tester.pump();
    verify(() => cubit.changeWorkspace('/picked')).called(1);
  });

  testWidgets('connects the agent with a prompt that names the task file', (
    tester,
  ) async {
    final cubit = _mockCubit(
      TasksLoaded(tasks: [open, done], selectedTaskId: 'f1'),
    );

    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('connect_agent')));
    await tester.pump();

    final launch =
        verify(() => launcher.launch(captureAny())).captured.single
            as AgentLaunch;
    expect(launch.agent, 'claude');
    expect(launch.workingDirectory, open.workingDirectory);
    expect(launch.prompt, contains('"Flutter PR"'));
    expect(launch.prompt, contains(open.location!));
    expect(launch.prompt, contains('Ask me which of the checklist items'));
    expect(launch.sessionId, isNull);

    // Hovering an item reveals "ask about this item". Its message is about
    // that item alone: the general prompt, which walks every item, is not
    // sent.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('merge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('button_ask_agent_item').first);
    await tester.pump();

    final focused =
        verify(() => launcher.launch(captureAny())).captured.single
            as AgentLaunch;
    expect(focused.prompt, contains(open.location!));
    expect(focused.prompt, contains('this one checklist item only: "merge"'));
    expect(focused.prompt, isNot(contains('Ask me which')));
    expect(focused.prompt, isNot(contains('"test"')));
  });

  testWidgets('reopens only after confirmation', (tester) async {
    final cubit = _mockCubit(
      TasksLoaded(tasks: [open, done], showDone: true, selectedTaskId: 'd1'),
    );

    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reopen_task')));
    await tester.pumpAndSettle();
    expect(find.text('text_confirm_reopen'), findsOneWidget);
    await tester.tap(find.text('button_cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => cubit.setStatus(taskId: 'd1', status: TaskStatus.open));

    await tester.tap(find.byKey(const Key('reopen_task')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('button_reopen').last);
    await tester.pumpAndSettle();
    verify(
      () => cubit.setStatus(taskId: 'd1', status: TaskStatus.open),
    ).called(1);
  });

  testWidgets('a first start welcomes instead of failing', (tester) async {
    final cubit = _mockCubit(
      const TasksError(message: 'No workspace folder chosen yet'),
    );

    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    expect(find.text('text_welcome'), findsOneWidget);
    expect(find.text('text_error_load'), findsNothing);
    expect(find.text('button_retry'), findsNothing);

    await tester.tap(find.text('button_choose_folder'));
    await tester.pump();
    verify(() => cubit.changeWorkspace('/picked')).called(1);
  });

  testWidgets('opens the settings menu and switches language and theme', (
    tester,
  ) async {
    final cubit = _mockCubit(
      TasksLoaded(tasks: [open, done], selectedTaskId: 'f1'),
    );

    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('menu_language'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('language_tr')), findsOneWidget);
    await tester.tap(find.byKey(const Key('language_tr')));
    await tester.pumpAndSettle();
    expect(localizor.changedTo, const Locale('tr'));

    await tester.tap(find.byKey(const Key('settings_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('menu_appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance_dark')));
    await tester.pumpAndSettle();
    verify(() => themes.changeThemeMode(any(), ThemeMode.dark)).called(1);
  });

  testWidgets('shows the error state and retries', (tester) async {
    final cubit = _mockCubit(
      const TasksError(message: '/nope missing', workspace: '/nope'),
    );

    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();
    expect(find.text('/nope missing'), findsOneWidget);

    await tester.tap(find.text('button_retry'));
    await tester.pumpAndSettle();

    verify(cubit.start).called(2);
  });
}

MockTasksCubit _mockCubit(TasksState state) {
  final cubit = MockTasksCubit();
  whenListen(cubit, const Stream<TasksState>.empty(), initialState: state);
  when(cubit.start).thenAnswer((_) async {});
  when(
    () => cubit.setActionDone(
      taskId: any(named: 'taskId'),
      index: any(named: 'index'),
      isDone: any(named: 'isDone'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => cubit.setStatus(
      taskId: any(named: 'taskId'),
      status: any(named: 'status'),
    ),
  ).thenAnswer((_) async {});
  when(() => cubit.changeWorkspace(any())).thenAnswer((_) async {});

  return cubit;
}

Widget _app(TasksCubit cubit) {
  return MaterialApp(
    navigatorObservers: [ViewRouteObserver.instance],
    home: BlocProvider<TasksCubit>.value(value: cubit, child: TasksPage()),
  );
}

class MockTasksCubit extends MockCubit<TasksState> implements TasksCubit {}

class MockExternalOpener extends Mock implements ExternalOpener {}

class MockFolderPicker extends Mock implements FolderPicker {}

class MockDockBadge extends Mock implements DockBadge {}

class MockAgentLauncher extends Mock implements AgentLauncher {}

class MockThemeManager extends Mock implements ThemeManager {}

class _FakeContext extends Fake implements BuildContext {}

/// Returns every key as its own translation (plus any named arguments, so a
/// prompt can be checked for what went into it), which keeps assertions
/// readable.
class _EchoLocalizor implements Localizor {
  Locale? changedTo;

  @override
  String tr(
    String text, {
    num? pluralValue,
    List<String>? args,
    Map<String, String>? namedArgs,
  }) => namedArgs == null ? text : '$text ${namedArgs.values.join(' ')}';

  @override
  String translate(
    String text, {
    num? pluralValue,
    List<String>? args,
    Map<String, String>? namedArgs,
  }) => text;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> changeLocale(BuildContext context, Locale newLocale) async {
    changedTo = newLocale;
  }

  @override
  Locale getDeviceLocale(BuildContext context) => const Locale('en');

  @override
  Locale? getSavedLocale(BuildContext context) => null;

  @override
  Future<void> useDeviceLocale(BuildContext context) async {}

  @override
  Locale getLocale(BuildContext context) => const Locale('en');

  @override
  List<LocalizationsDelegate<dynamic>> getLocalizationDelegates(
    BuildContext context,
  ) => const [];

  @override
  List<Locale> getSupportedLocales(BuildContext context) => const [
    Locale('en'),
  ];
}
