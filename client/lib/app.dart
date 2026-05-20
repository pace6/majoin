import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/encryption.dart';
import 'package:provider/provider.dart';
import 'core/auth/login_controller.dart';
import 'core/auth/register_controller.dart';
import 'core/client/matrix_client.dart';
import 'core/encryption/key_service.dart';
import 'core/i18n/strings.dart';
import 'core/push/push_service.dart';
import 'features/call/call_service.dart';
import 'features/rooms/add_friends_screen.dart';
import 'features/security/key_backup_gate.dart';
import 'features/security/verification_sheet.dart';
import 'ui/pages/login_page.dart';
import 'ui/pages/register_page.dart';
import 'ui/pages/security_page.dart';
import 'ui/pages/welcome_page.dart';
import 'ui/shells/desktop_shell.dart';
import 'ui/shells/mobile_shell.dart';
import 'ui/theme/app_theme.dart';

class MajoinApp extends StatefulWidget {
  const MajoinApp({super.key});

  @override
  State<MajoinApp> createState() => _MajoinAppState();
}

class _MajoinAppState extends State<MajoinApp> {
  late final GoRouter _router;
  final _navKey = GlobalKey<NavigatorState>();
  PushService? _push;
  bool _callInit = false;
  StreamSubscription<KeyVerification>? _verifSub;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      navigatorKey: _navKey,
      refreshListenable: MatrixClientService.instance,
      redirect: (context, state) {
        final logged =
            MatrixClientService.instance.hasClient && MatrixClientService.instance.isLoggedIn;
        final atAuth = state.matchedLocation == '/welcome' ||
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';
        if (!logged && !atAuth) return '/welcome';
        if (logged && atAuth) return '/rooms';
        return null;
      },
      routes: [
        GoRoute(path: '/', redirect: (_, __) => '/rooms'),
        GoRoute(
          path: '/welcome',
          builder: (_, __) => const WelcomePage(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => ChangeNotifierProvider(
            create: (_) => LoginController(),
            child: const LoginPage(),
          ),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => ChangeNotifierProvider(
            create: (_) => RegisterController(),
            child: const RegisterPage(),
          ),
        ),
        GoRoute(
          path: '/security',
          builder: (_, __) => const SecurityPage(),
        ),
        GoRoute(
          path: '/add-friends',
          builder: (_, __) => const AddFriendsScreen(),
        ),
        GoRoute(
          path: '/rooms',
          builder: (_, __) => const _AdaptiveHome(),
          routes: [
            GoRoute(
              path: ':roomId',
              builder: (context, state) {
                final id = Uri.decodeComponent(state.pathParameters['roomId']!);
                final room = MatrixClientService.instance.client.getRoomById(id);
                if (room == null) return const Scaffold(body: Center(child: Text('Room not found')));
                return MobileTimelinePage(room: room);
              },
            ),
          ],
        ),
      ],
    );

    // Push: init once we have a client + logged in.
    MatrixClientService.instance.addListener(_maybeInitPush);
  }

  void _maybeInitPush() {
    final svc = MatrixClientService.instance;
    if (!svc.hasClient || !svc.isLoggedIn) return;
    if (_push == null) {
      _push = PushService(svc.client, _navKey)..init();
    }
    if (!_callInit) {
      _callInit = true;
      CallService.init(_navKey);
    }
    // Surface incoming key-verification requests (another device wants to
    // verify us) as a modal, wherever the user currently is.
    _verifSub ??=
        KeyService.instance.incomingVerifications.listen((request) {
      final ctx = _navKey.currentContext;
      if (ctx != null) VerificationSheet.show(ctx, request);
    });
  }

  @override
  void dispose() {
    MatrixClientService.instance.removeListener(_maybeInitPush);
    _verifSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LocaleController.instance,
      builder: (_, __) => MaterialApp.router(
        title: 'majoin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        locale: LocaleController.instance.locale,
        supportedLocales: const [Locale('th'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
      ),
    );
  }
}

class _AdaptiveHome extends StatefulWidget {
  const _AdaptiveHome();
  @override
  State<_AdaptiveHome> createState() => _AdaptiveHomeState();
}

class _AdaptiveHomeState extends State<_AdaptiveHome> {
  @override
  void initState() {
    super.initState();
    // On the home screen, make sure encryption key backup is set up (or
    // restored on this device) so encrypted history survives reinstalls.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybePromptKeyBackup(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final desktop = c.maxWidth >= 900;
        return desktop ? const DesktopShell() : const MobileShell();
      },
    );
  }
}
