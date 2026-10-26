import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/services/app_session.dart';
import 'theme/app_theme.dart';
import '../features/account/account_screens.dart';
import '../features/account/account_controls.dart';

class PlanifyApp extends StatelessWidget {
  final AppSession session;
  const PlanifyApp({super.key, required this.session});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => MaterialApp(
      key: ValueKey(session.account != null),
      title: 'Planify',
      debugShowCheckedModeBanner: false,
      theme: PlanifyTheme.build(Brightness.light),
      darkTheme: PlanifyTheme.build(Brightness.dark),
      themeMode: switch (session.account?.theme) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      locale: Locale(session.account?.language ?? 'en'),
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            if (settings.name == '/help') {
              return Scaffold(
                appBar: AppBar(title: const Text('Planify')),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: AccountHelpPage(
                        session: session.account == null ? null : session,
                      ),
                    ),
                  ),
                ),
              );
            }
            if (session.restoring) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (session.restoreError != null) {
              return Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 340,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Brand(),
                        const SizedBox(height: 32),
                        Text(
                          session.restoreError!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: session.restore,
                          child: const Text('Retry connection'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await session.signOut();
                            session.restoreError = null;
                            await session.restore();
                          },
                          child: const Text('Return to sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (session.account == null) {
              return AuthScreen(
                session: session,
                initialMode: settings.name == '/register'
                    ? 'register'
                    : settings.name == '/forgot-password'
                    ? 'forgot'
                    : 'login',
              );
            }
            if (settings.name == '/security') {
              return Scaffold(
                appBar: AppBar(
                  title: Text(tr(context, 'Security', 'Sécurité')),
                  actions: [
                    IconButton(
                      tooltip: tr(context, 'My space', 'Mon espace'),
                      icon: const Icon(Icons.home_outlined),
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/'),
                    ),
                  ],
                ),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Entrance(child: SecurityPage(session: session)),
                    ),
                  ),
                ),
              );
            }
            return AccountShell(
              session: session,
              initialTab: switch (settings.name) {
                '/preferences' => 1,
                '/privacy' => 2,
                '/analytics' => 3,
                _ => 0,
              },
            );
          },
        ),
      ),
    ),
  );
}
