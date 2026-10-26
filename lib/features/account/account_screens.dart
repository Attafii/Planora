import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/services/app_session.dart';
import 'account_controls.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/planify_brand.dart';

String tr(BuildContext context, String en, String fr) =>
    Localizations.localeOf(context).languageCode == 'fr' ? fr : en;

class Brand extends StatelessWidget {
  final bool inverted;
  const Brand({super.key, this.inverted = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const PlanifyMark(size: 40),
      const SizedBox(width: 9),
      Text(
        'Planify',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          fontSize: 25,
          letterSpacing: -1.1,
          color: inverted || Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : PlanifyTheme.ink,
        ),
      ),
    ],
  );
}

class Entrance extends StatelessWidget {
  final Widget child;
  const Entrance({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 440,
    ),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * 16),
        child: child,
      ),
    ),
    child: child,
  );
}

class AuthScreen extends StatefulWidget {
  final AppSession session;
  final String initialMode;
  const AuthScreen({
    super.key,
    required this.session,
    this.initialMode = 'login',
  });
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      confirm = TextEditingController();
  late String mode = widget.initialMode;
  bool busy = false, hidden = true;
  String? error;
  Map<String, dynamic> fields = {};
  void change(String value) {
    setState(() {
      mode = value;
      error = null;
      fields = {};
      password.clear();
      confirm.clear();
    });
    form.currentState?.reset();
  }

  @override
  void dispose() {
    for (final c in [email, password, name, confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      fields = {};
      error = null;
    });
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.session.authenticate(
        register: mode == 'register',
        email: email.text,
        password: password.text,
        name: name.text,
      );
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          fields = e.fields;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final register = mode == 'register', forgot = mode == 'forgot';
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final content = Padding(
      padding: EdgeInsets.all(wide ? 52 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(alignment: Alignment.centerLeft, child: Brand()),
              const SizedBox(height: 48),
              Text(
                forgot
                    ? 'A little help getting back.'
                    : register
                    ? 'Make space for you.'
                    : 'A fresh start,\nat your pace.',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 42,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                forgot
                    ? 'Let’s help you find your way back to Planify.'
                    : register
                    ? 'Create your account. A calmer everyday starts here.'
                    : 'Welcome back. Settle in and make yourself at home.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openAccountPanel(
                    context,
                    tr(context, 'Account help', 'Aide du compte'),
                    const AccountHelpPage(),
                  ),
                  icon: const Icon(Icons.help_outline_rounded, size: 18),
                  label: Text(
                    tr(
                      context,
                      'Need a little guidance?',
                      'Besoin d’un conseil ?',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (forgot) ...[
                const Notice(
                  icon: Icons.mail_outline_rounded,
                  text: 'Password recovery is not available yet. Our email service is still being connected. No reset email has been sent.',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => change('login'),
                  child: const Text('Back to sign in'),
                ),
              ] else
                Form(
                  key: form,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (register) ...[
                          TextFormField(
                            controller: name,
                            autofillHints: const [AutofillHints.name],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Your name',
                              errorText: fields['name'] as String?,
                            ),
                            validator: (v) =>
                                v!.trim().length < 2 || v.trim().length > 80
                                ? 'Use 2–80 characters.'
                                : null,
                          ),
                          const SizedBox(height: 18),
                        ],
                        TextFormField(
                          controller: email,
                          autofillHints: const [AutofillHints.email],
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                              size: 20,
                            ),
                            errorText: fields['email'] as String?,
                          ),
                          validator: (v) =>
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(v!.trim())
                              ? 'Enter a valid email address.'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: password,
                          obscureText: hidden,
                          autofillHints: [
                            register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          textInputAction: register
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!register && !busy) submit();
                          },
                          decoration: InputDecoration(
                            labelText: 'Password',
                            helperText: register
                                ? '12–128 characters. Make it something only you know.'
                                : null,
                            helperMaxLines: 2,
                            errorText: fields['password'] as String?,
                            suffixIcon: IconButton(
                              tooltip: hidden
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(() => hidden = !hidden),
                              icon: Icon(
                                hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                          validator: (v) => v!.isEmpty
                              ? 'Enter your password.'
                              : register && (v.length < 12 || v.length > 128)
                              ? 'Use 12–128 characters.'
                              : null,
                        ),
                        if (register) ...[
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: confirm,
                            obscureText: hidden,
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!busy) submit();
                            },
                            decoration: const InputDecoration(
                              labelText: 'Confirm password',
                            ),
                            validator: (v) => v != password.text
                                ? 'Your passwords do not match.'
                                : null,
                          ),
                        ],
                        if (!register)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy ? null : () => change('forgot'),
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Notice(
                              text: error!,
                              icon: Icons.info_outline,
                              isError: true,
                            ),
                          ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: busy ? null : submit,
                          child: busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        register
                                            ? 'Create my account'
                                            : 'Sign in',
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 20,
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              register
                                  ? 'Already feel at home? '
                                  : 'New to Planify? ',
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                        change(register ? 'login' : 'register'),
                              child: Text(
                                register ? 'Sign in' : 'Create an account',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 15),
                  SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'Plan your day. Make room for life.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: Entrance(key: ValueKey(mode), child: content),
                    ),
                    if (wide)
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: WelcomeArt(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeArt extends StatelessWidget {
  const WelcomeArt({super.key});
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 700),
    padding: const EdgeInsets.all(44),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD9F8F8), Color(0xFFE9EEFF), Color(0xFFE9DEFF)],
      ),
      borderRadius: BorderRadius.circular(32),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Plan with',
          style: TextStyle(
            fontFamily: 'Manrope',
            color: PlanifyTheme.ink,
            fontSize: 48,
            fontWeight: FontWeight.w800,
            letterSpacing: -2,
            height: 1.15,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) =>
              PlanifyTheme.brandGradient.createShader(bounds),
          child: const Text(
            'clarity.',
            style: TextStyle(
              fontFamily: 'Manrope',
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w800,
              letterSpacing: -2,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Plan your day. Make room for life.',
          style: TextStyle(
            fontFamily: 'Inter',
            color: PlanifyTheme.ink,
            fontSize: 17,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 50),
        Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 28),
            decoration: BoxDecoration(
              color: PlanifyTheme.cream,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: PlanifyTheme.ink.withValues(alpha: .08),
                  blurRadius: 44,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: PlanifyMark(size: 140)),
                const SizedBox(height: 30),
                const Text(
                  'Your day,\nyour way.',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    color: PlanifyTheme.ink,
                    fontSize: 30,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'A flexible path.\nSteady progress.',
                  style: TextStyle(
                    color: PlanifyTheme.ink,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: PlanifyTheme.brandGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 42),
        const Text(
          'A little room for what matters.',
          style: TextStyle(color: PlanifyTheme.ink, fontSize: 14),
        ),
      ],
    ),
  );
}

class Notice extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isError;
  const Notice({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.isError = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isError
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
        ],
      ),
    ),
  );
}

class AccountShell extends StatefulWidget {
  final AppSession session;
  final int initialTab;
  const AccountShell({super.key, required this.session, this.initialTab = 0});
  @override
  State<AccountShell> createState() => _AccountShellState();
}

class _AccountShellState extends State<AccountShell> {
  late int tab = widget.initialTab;
  bool signingOut = false;
  @override
  Widget build(BuildContext context) {
    final labels = [
      tr(context, 'My space', 'Mon espace'),
      tr(context, 'Preferences', 'Préférences'),
      tr(context, 'Privacy', 'Confidentialité'),
      tr(context, 'Insights', 'Statistiques'),
    ];
    const icons = [
      Icons.person_outline_rounded,
      Icons.tune_rounded,
      Icons.shield_outlined,
      Icons.insights_rounded,
    ];
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final pages = [
      ProfilePage(
        session: widget.session,
        navigate: (i) => setState(() => tab = i),
      ),
      PreferencesPage(session: widget.session),
      PrivacyPage(session: widget.session),
      InsightsPage(session: widget.session),
    ];
    return Scaffold(
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: List.generate(
                4,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: labels[i],
                ),
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 246,
                padding: const EdgeInsets.fromLTRB(28, 32, 20, 24),
                decoration: BoxDecoration(
                  color: PlanifyTheme.ink,
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).dividerColor
                          .withValues(alpha: .12),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Brand(inverted: true),
                    ),
                    const SizedBox(height: 56),
                    Text(
                      tr(context, 'A SPACE FOR YOU', 'VOTRE ESPACE'),
                      style: const TextStyle(
                        color: Color(0xFFB8CBEA),
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ...List.generate(
                      4,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            selected: tab == i,
                            selectedTileColor: const Color(0xFF19386B),
                            selectedColor: Colors.white,
                            textColor: const Color(0xFFD4DEF0),
                            iconColor: const Color(0xFFB8CBEA),
                            leading: Icon(icons[i], size: 22),
                            title: Text(
                              labels[i],
                              style: const TextStyle(fontSize: 14),
                            ),
                            onTap: () => setState(() => tab = i),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const PlanifyMark(size: 36),
                    const SizedBox(height: 14),
                    Text(
                      tr(
                        context,
                        'Good things take\na little space.',
                        'Les belles choses\nprennent leur temps.',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 44 : 20,
                      vertical: 20,
                    ),
                    child: Row(
                      children: [
                        if (!wide)
                          const Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Brand(),
                              ),
                            ),
                          )
                        else
                          Text(
                            labels[tab],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        if (wide) const Spacer(),
                        IconButton(
                          tooltip: tr(
                            context,
                            'Account help',
                            'Aide du compte',
                          ),
                          icon: const Icon(Icons.help_outline_rounded),
                          onPressed: () => openAccountPanel(
                            context,
                            tr(context, 'Account help', 'Aide du compte'),
                            AccountHelpPage(session: widget.session),
                          ),
                        ),
                        IconButton(
                          tooltip: tr(context, 'Security', 'Sécurité'),
                          icon: const Icon(Icons.fingerprint_rounded),
                          onPressed: () => openAccountPanel(
                            context,
                            tr(context, 'Security', 'Sécurité'),
                            SecurityPage(session: widget.session),
                          ),
                        ),
                        IconButton(
                          tooltip: tr(context, 'Sign out', 'Se déconnecter'),
                          onPressed: signingOut
                              ? null
                              : () async {
                                  setState(() => signingOut = true);
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    final revoked = await widget.session
                                        .signOut();
                                    if (!revoked) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Signed out on this device. The server session could not be revoked and will expire automatically.',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (_) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Secure storage could not be cleared. Please clear this app’s device data before leaving a shared device.',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => signingOut = false);
                                    }
                                  }
                                },
                          icon: const Icon(Icons.logout_rounded, size: 21),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 44 : 20,
                        12,
                        wide ? 44 : 20,
                        36,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: AnimatedSwitcher(
                            duration: Duration(
                              milliseconds:
                                  MediaQuery.disableAnimationsOf(context)
                                  ? 0
                                  : 220,
                            ),
                            child: Entrance(
                              key: ValueKey(tab),
                              child: pages[tab],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  const PageHeading({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 34,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.2,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class ProfilePage extends StatelessWidget {
  final AppSession session;
  final ValueChanged<int> navigate;
  const ProfilePage({super.key, required this.session, required this.navigate});
  @override
  Widget build(BuildContext context) {
    final u = session.account!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading(
          title: tr(
            context,
            'Hello, ${u.name.split(' ').first}.',
            'Bonjour, ${u.name.split(' ').first}.',
          ),
          subtitle: tr(
            context,
            'A little space to make Planify feel like you.',
            'Un espace pour personnaliser Planify à votre image.',
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: PlanifyTheme.lavender,
                      child: Text(
                        u.name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 26,
                          color: PlanifyTheme.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.name,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(u.email, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr(
                        context,
                        'Edit profile',
                        'Modifier le profil',
                      ),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => EditProfileDialog(session: session),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                const Divider(),
                Wrap(
                  spacing: 36,
                  runSpacing: 20,
                  children: [
                    Detail(
                      icon: Icons.public_rounded,
                      label: tr(context, 'TIMEZONE', 'FUSEAU HORAIRE'),
                      value: u.timezone,
                    ),
                    Detail(
                      icon: Icons.translate_rounded,
                      label: tr(context, 'LANGUAGE', 'LANGUE'),
                      value: u.language == 'fr' ? 'Français' : 'English',
                    ),
                    Detail(
                      icon: Icons.verified_user_outlined,
                      label: tr(context, 'ACCOUNT', 'COMPTE'),
                      value: tr(
                        context,
                        'Active · email unverified',
                        'Actif · e-mail non vérifié',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ProfileQualityCard(session: session, onPreferences: () => navigate(1)),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(22),
            leading: const Icon(Icons.fingerprint_rounded),
            title: Text(
              tr(context, 'Security and devices', 'Sécurité et appareils'),
            ),
            subtitle: Text(
              tr(
                context,
                'Sessions and recent account notices.',
                'Sessions et notifications récentes du compte.',
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_rounded),
            onTap: () => openAccountPanel(
              context,
              tr(context, 'Security', 'Sécurité'),
              SecurityPage(session: session),
            ),
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, box) {
            final tiles = [
              ActionTile(
                icon: Icons.tune_rounded,
                color: PlanifyTheme.tealTint,
                title: tr(context, 'Find your rhythm', 'Trouvez votre rythme'),
                text: tr(
                  context,
                  'Language, timezone and the look you love.',
                  'Langue, fuseau horaire et apparence.',
                ),
                onTap: () => navigate(1),
              ),
              ActionTile(
                icon: Icons.shield_outlined,
                color: PlanifyTheme.lavender,
                title: tr(
                  context,
                  'You’re in control',
                  'Vous gardez le contrôle',
                ),
                text: tr(
                  context,
                  'Your data and your choices, made clear.',
                  'Vos données et vos choix, en toute clarté.',
                ),
                onTap: () => navigate(2),
              ),
            ];
            return box.maxWidth > 600
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: tiles[0]),
                      const SizedBox(width: 20),
                      Expanded(child: tiles[1]),
                    ],
                  )
                : Column(
                    children: [tiles[0], const SizedBox(height: 16), tiles[1]],
                  );
          },
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(22),
            leading: const Icon(Icons.insights_rounded),
            title: Text(
              tr(context, 'Every small step counts', 'Chaque petit pas compte'),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr(
                  context,
                  'Explore your recorded activity, at your pace.',
                  'Découvrez votre activité enregistrée, à votre rythme.',
                ),
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_rounded),
            onTap: () => navigate(3),
          ),
        ),
      ],
    );
  }
}

class Detail extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const Detail({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontSize: 10, letterSpacing: 1)),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ],
  );
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, text;
  final VoidCallback onTap;
  const ActionTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: PlanifyTheme.ink),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(height: 1.6)),
          ],
        ),
      ),
    ),
  );
}

class EditProfileDialog extends StatefulWidget {
  final AppSession session;
  const EditProfileDialog({super.key, required this.session});
  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final name = TextEditingController(text: widget.session.account!.name);
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      tr(context, 'A name that feels like you', 'Un nom qui vous ressemble'),
    ),
    content: SizedBox(
      width: 400,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: tr(context, 'Display name', 'Nom affiché'),
              ),
              validator: (v) => v!.trim().length < 2 || v.trim().length > 80
                  ? tr(
                      context,
                      'Use 2–80 characters.',
                      'Utilisez 2 à 80 caractères.',
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              tr(
                context,
                'Email changes will be available after email verification is connected. Your login email stays the same.',
                'La modification de l’e-mail sera disponible après la configuration du service de vérification.',
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Notice(text: error!, isError: true),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(tr(context, 'Cancel', 'Annuler')),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                if (!form.currentState!.validate()) return;
                setState(() => busy = true);
                try {
                  await widget.session.saveProfile(name.text.trim());
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) setState(() => error = e.toString());
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
        child: Text(
          busy
              ? tr(context, 'Saving…', 'Enregistrement…')
              : tr(context, 'Save changes', 'Enregistrer'),
        ),
      ),
    ],
  );
}

class PreferencesPage extends StatefulWidget {
  final AppSession session;
  const PreferencesPage({super.key, required this.session});
  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  late String timezone = widget.session.account!.timezone,
      language = widget.session.account!.language,
      theme = widget.session.account!.theme;
  bool busy = false;
  String? error;
  bool saved = false;
  @override
  Widget build(BuildContext context) {
    final locations = tz.timeZoneDatabase.locations.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading(
          title: tr(context, 'Make it feel like you.', 'À votre image.'),
          subtitle: tr(
            context,
            'Little preferences that make a big difference.',
            'Les petits réglages qui font la différence.',
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(context, 'Your everyday', 'Votre quotidien'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                DropdownMenu<String>(
                  initialSelection: timezone,
                  expandedInsets: EdgeInsets.zero,
                  enableFilter: true,
                  requestFocusOnTap: true,
                  label: Text(tr(context, 'Timezone', 'Fuseau horaire')),
                  dropdownMenuEntries: locations
                      .map((v) => DropdownMenuEntry(value: v, label: v))
                      .toList(),
                  onSelected: busy
                      ? null
                      : (v) {
                          if (v != null) {
                            setState(() {
                              timezone = v;
                              saved = false;
                            });
                          }
                        },
                ),
                const SizedBox(height: 10),
                Text(
                  tr(
                    context,
                    'Calendar days and insights follow this timezone.',
                    'Les dates et statistiques utilisent ce fuseau horaire.',
                  ),
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 26),
                DropdownButtonFormField<String>(
                  initialValue: language,
                  decoration: InputDecoration(
                    labelText: tr(context, 'Language', 'Langue'),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'fr', child: Text('Français')),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          language = v!;
                          saved = false;
                        }),
                ),
                const SizedBox(height: 26),
                Text(
                  tr(context, 'A comfortable view', 'Une vue confortable'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final option in ['light', 'dark', 'system'])
                      ChoiceChip(
                        label: Text(switch (option) {
                          'light' => tr(context, 'Light', 'Clair'),
                          'dark' => tr(context, 'Dark', 'Sombre'),
                          _ => tr(context, 'System', 'Système'),
                        }),
                        selected: theme == option,
                        onSelected: busy
                            ? null
                            : (_) => setState(() {
                                theme = option;
                                saved = false;
                              }),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Notice(
                  text: tr(
                    context,
                    'Notification delivery is not connected yet. There are no notification settings to configure.',
                    'Le service de notifications n’est pas encore connecté. Aucun réglage n’est disponible.',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 20),
                  Notice(text: error!, isError: true),
                ],
                if (saved) ...[
                  const SizedBox(height: 20),
                  Notice(
                    text: tr(
                      context,
                      'Your preferences are saved.',
                      'Vos préférences sont enregistrées.',
                    ),
                    icon: Icons.check_circle_outline,
                  ),
                ],
                const SizedBox(height: 26),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() {
                              busy = true;
                              error = null;
                              saved = false;
                            });
                            try {
                              await widget.session.savePreferences({
                                'timezone': timezone,
                                'language': language,
                                'theme': theme,
                              });
                              if (mounted) setState(() => saved = true);
                            } catch (e) {
                              if (mounted) setState(() => error = e.toString());
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: Text(
                      busy
                          ? tr(context, 'Saving…', 'Enregistrement…')
                          : tr(context, 'Save preferences', 'Enregistrer'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PrivacyPage extends StatelessWidget {
  final AppSession session;
  const PrivacyPage({super.key, required this.session});
  @override
  Widget build(BuildContext context) => AccountPrivacyPage(session: session);
}

/// Calendar boundaries are computed in the saved IANA zone, then sent as UTC.
/// The API uses an inclusive start and an exclusive end, including across DST.
({DateTime from, DateTime to}) analyticsRange(
  String timezone,
  String range,
  DateTime instant,
) {
  final location = tz.getLocation(timezone),
      local = tz.TZDateTime.from(instant, tz.getLocation(timezone));
  final today = tz.TZDateTime(location, local.year, local.month, local.day);
  final from = range == 'month'
      ? tz.TZDateTime(location, local.year, local.month)
      : tz.TZDateTime(
          location,
          today.year,
          today.month,
          today.day - (today.weekday - 1),
        );
  final to = tz.TZDateTime(location, local.year, local.month, local.day + 1);
  return (from: from.toUtc(), to: to.toUtc());
}

class InsightsPage extends StatefulWidget {
  final AppSession session;
  const InsightsPage({super.key, required this.session});
  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  String range = 'week';
  late Future<Map<String, dynamic>> data = load();
  Future<Map<String, dynamic>> load() {
    final dates = analyticsRange(
      widget.session.account!.timezone,
      range,
      DateTime.now(),
    );
    return widget.session.request(
      'GET',
      '/users/me/analytics?from=${Uri.encodeQueryComponent(dates.from.toIso8601String())}&to=${Uri.encodeQueryComponent(dates.to.toIso8601String())}',
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeading(
        title: tr(context, 'A moment to reflect.', 'Un moment pour réfléchir.'),
        subtitle: tr(
          context,
          'Your recorded progress, without the pressure.',
          'Vos progrès enregistrés, sans pression.',
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'week',
              label: Text(tr(context, 'This week', 'Cette semaine')),
            ),
            ButtonSegment(
              value: 'month',
              label: Text(tr(context, 'This month', 'Ce mois')),
            ),
          ],
          selected: {range},
          onSelectionChanged: (v) => setState(() {
            range = v.first;
            data = load();
          }),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        '${tr(context, 'Calendar timezone', 'Fuseau horaire')} · ${widget.session.account!.timezone}',
        style: const TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 24),
      FutureBuilder<Map<String, dynamic>>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(60),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                Notice(text: snapshot.error.toString(), isError: true),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => setState(() => data = load()),
                  icon: const Icon(Icons.refresh),
                  label: Text(tr(context, 'Try again', 'Réessayer')),
                ),
              ],
            );
          }
          final result = snapshot.data!;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: PlanifyTheme.lavender,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      size: 36,
                      color: PlanifyTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    result['status'] == 'unavailable'
                        ? tr(
                            context,
                            'Your story is taking shape.',
                            'Votre histoire prend forme.',
                          )
                        : tr(
                            context,
                            'Small steps, recorded.',
                            'Vos petits pas, enregistrés.',
                          ),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (result['status'] == 'unavailable')
                    Text(
                      tr(
                        context,
                        'Activity sources are not connected yet. Completed tasks and goals will appear here once verified records are available.',
                        'Les sources d’activité ne sont pas encore connectées. Les tâches et objectifs terminés apparaîtront lorsque les données vérifiées seront disponibles.',
                      ),
                      style: const TextStyle(fontSize: 15, height: 1.7),
                    ),
                  const SizedBox(height: 24),
                  if (result['status'] == 'unavailable')
                    Notice(
                      text: tr(
                        context,
                        'Unavailable is different from zero. No activity totals or productivity scores have been estimated.',
                        'Indisponible ne signifie pas zéro. Aucun total ni score de productivité n’a été estimé.',
                      ),
                    ),
                  if (result['status'] != 'unavailable') ...[
                    if (result['tasks_completed'] != null)
                      Semantics(
                        label:
                            '${tr(context, 'Completed tasks', 'Tâches terminées')}: ${result['tasks_completed']}',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text(
                            tr(context, 'Completed tasks', 'Tâches terminées'),
                          ),
                          trailing: Text(
                            '${result['tasks_completed']}',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (result['goals_completed'] != null)
                      Semantics(
                        label:
                            '${tr(context, 'Completed goals', 'Objectifs terminés')}: ${result['goals_completed']}',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.flag_outlined),
                          title: Text(
                            tr(
                              context,
                              'Completed goals',
                              'Objectifs terminés',
                            ),
                          ),
                          trailing: Text(
                            '${result['goals_completed']}',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Notice(
                      text: result['status'] == 'partial'
                          ? tr(
                              context,
                              'Some activity sources are unavailable. Only verified totals are shown.',
                              'Certaines sources sont indisponibles. Seuls les totaux vérifiés sont affichés.',
                            )
                          : tr(
                              context,
                              'Each total counts your currently accessible completed records once. This period includes today and is still in progress.',
                              'Chaque total compte une fois vos éléments terminés encore accessibles. Cette période inclut aujourd’hui et reste en cours.',
                            ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    '${tr(context, 'Updated', 'Mis à jour')} ${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).add_Hm().format(tz.TZDateTime.from(DateTime.parse(result['generated_at'] as String), tz.getLocation(widget.session.account!.timezone)))}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => setState(() => data = load()),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(tr(context, 'Refresh insights', 'Actualiser')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}
