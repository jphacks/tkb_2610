import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/controller.dart';
import 'core/theme.dart';
import 'core/evolution_sound.dart';
import 'features/evolution_scene.dart';
import 'data/models.dart';
import 'features/home.dart';
import 'features/registration.dart';
import 'features/deed_entry.dart';
import 'features/status.dart';
import 'features/gallery.dart';
import 'features/settings.dart';
import 'features/generation.dart';
import 'widgets/common.dart';
import 'widgets/navigation.dart';

class YoinokoApp extends StatefulWidget {
  const YoinokoApp({
    super.key,
    required this.controller,
    this.isDemo = true,
    this.evolutionSoundFactory,
  });
  final GameController controller;
  final bool isDemo;
  final EvolutionSound Function()? evolutionSoundFactory;
  @override
  State<YoinokoApp> createState() => _YoinokoAppState();
}

class _YoinokoAppState extends State<YoinokoApp> with WidgetsBindingObserver {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    try {
      await widget.controller.refresh();
    } catch (e) {
      if (mounted) {
        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(GameController.message(e)),
            action: SnackBarAction(label: '再試行', onPressed: refresh),
          ),
        );
      }
    }
  }

  Widget watch(Widget Function() build, {bool requiresSession = true}) =>
      AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) =>
            requiresSession && widget.controller.snapshot == null
            ? const SizedBox.shrink()
            : build(),
      );
  Page<void> tabPage(GoRouterState state, Widget Function() build) =>
      NoTransitionPage<void>(key: state.pageKey, child: watch(build));

  late final GoRouter router = GoRouter(
    initialLocation: '/home',
    refreshListenable: widget.controller,
    redirect: (context, state) {
      final c = widget.controller;
      if (c.loading || c.error != null) {
        return state.uri.path == '/loading' ? null : '/loading';
      }
      if (c.snapshot == null) {
        return state.uri.path == '/register' ? null : '/register';
      }
      if (state.uri.path == '/register' || state.uri.path == '/loading') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => watch(
          () => Scaffold(
            body: SafeArea(
              child: Center(
                child: widget.controller.error == null
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ErrorNotice(widget.controller.error!),
                            PrimaryButton(
                              label: '再読み込み',
                              onPressed: widget.controller.initialize,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          requiresSession: false,
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => watch(
          () => RegistrationPage(controller: widget.controller),
          requiresSession: false,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => _Shell(
          controller: widget.controller,
          location: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => tabPage(
              state,
              () =>
                  widget.controller.snapshot!.current.stage == LifeStage.active
                  ? HomePage(controller: widget.controller)
                  : GenerationPage(controller: widget.controller),
            ),
          ),
          GoRoute(
            path: '/status',
            pageBuilder: (context, state) =>
                tabPage(state, () => StatusPage(controller: widget.controller)),
          ),
          GoRoute(
            path: '/gallery',
            pageBuilder: (context, state) => tabPage(
              state,
              () => GalleryPage(controller: widget.controller),
            ),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => watch(
                  () => CharacterDetailPage(
                    controller: widget.controller,
                    characterId: state.pathParameters['id']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => tabPage(
              state,
              () => SettingsPage(
                controller: widget.controller,
                isDemo: widget.isDemo,
                evolutionSoundFactory: widget.evolutionSoundFactory,
              ),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => context.go('/home'),
          child: const Text('ホームへ戻る'),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'よいのこ',
    scaffoldMessengerKey: messengerKey,
    debugShowCheckedModeBanner: false,
    theme: yoinokoTheme(),
    routerConfig: router,
    builder: (context, child) => ColoredBox(
      color: const Color(0xFFDCE8EF),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final event = widget.controller.pendingEvolution;
              final showing = event != null && !widget.controller.composing;
              return Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      excluding: showing,
                      child: TickerMode(enabled: !showing, child: child!),
                    ),
                  ),
                  if (showing)
                    Positioned.fill(
                      child: EvolutionScene(
                        key: ValueKey(event.id),
                        event: event,
                        sound: widget.evolutionSoundFactory?.call(),
                        onClose: () {
                          widget.controller.finishEvolution(event.id);
                          router.go('/home');
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.controller,
    required this.location,
    required this.child,
  });
  final GameController controller;
  final String location;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final index = location.startsWith('/status')
        ? 1
        : location.startsWith('/gallery')
        ? 3
        : location.startsWith('/settings')
        ? 4
        : 0;
    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => YoinokoNavigation(
          index: controller.composing ? 2 : index,
          onSelect: (i) {
            if (i == 2) {
              if (controller.snapshot!.current.stage != LifeStage.active) {
                context.go('/home');
                return;
              }
              openDeedEntry(context, controller);
            } else {
              context.go(['/home', '/status', '', '/gallery', '/settings'][i]);
            }
          },
        ),
      ),
    );
  }
}
