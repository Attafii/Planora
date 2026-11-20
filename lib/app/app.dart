import 'package:flutter/material.dart';

import 'app_services.dart';
import 'theme/app_theme.dart';
import 'feature_shell.dart';
import 'auth_page.dart';
import 'router/app_router.dart';

class PlanifyApp extends StatefulWidget {
  const PlanifyApp({super.key, this.services});
  final AppServices? services;
  @override
  State<PlanifyApp> createState() => _PlanifyAppState();
}

class _PlanifyAppState extends State<PlanifyApp> {
  late final AppServices _services;
  String? _pendingRoute;
  @override
  void initState() {
    super.initState();
    _services = widget.services ?? AppServices();
    _pendingRoute = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    _services.session.initialize();
  }

  @override
  void dispose() {
    if (widget.services == null) {
      _services.session.dispose();
      _services.api.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    services: _services,
    child: ListenableBuilder(
      listenable: _services.session,
      builder: (context, child) {
        final session = _services.session;
        return MaterialApp(
          key: ValueKey(session.user?.id ?? 'signed-out'),
          title: 'Planify',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: session.loading
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : session.user == null
              ? const AuthPage()
              : const FeatureShell(),
          initialRoute:
              session.user != null &&
                  _pendingRoute != null &&
                  _pendingRoute != '/'
              ? _takeRoute()
              : null,
          onGenerateRoute: session.user == null
              ? (_) => MaterialPageRoute<void>(builder: (_) => const AuthPage())
              : AppRouter.route,
        );
      },
    ),
  );
  String? _takeRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }
}
