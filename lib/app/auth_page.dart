import 'package:flutter/material.dart';

import 'app_services.dart';
import 'theme/app_colors.dart';
import '../core/utils/validators.dart';
import '../core/widgets/product_widgets.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>(),
      _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController();
  bool _register = false, _hidden = true;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/branding/identity-source/approved-logo.png',
                      height: 110,
                      width: 340,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _register ? 'Make room for your goals.' : 'Welcome back.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _register
                          ? 'Create your account to start planning meaningful outcomes.'
                          : 'Sign in to your Planify workspace.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 28),
                    if (session.error != null) ...[
                      Text(
                        session.error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      TextButton(
                        onPressed: session.initialize,
                        child: const Text('Retry session connection'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_register) ...[
                      TextFormField(
                        controller: _name,
                        validator: Validators.required,
                        autofillHints: const [AutofillHints.name],
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _email,
                      validator: Validators.email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _password,
                      validator: Validators.password,
                      obscureText: _hidden,
                      autofillHints: [
                        _register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: 'At least 10 characters',
                        suffixIcon: IconButton(
                          tooltip: _hidden ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _hidden = !_hidden),
                          icon: Icon(
                            _hidden
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    BusyButton(
                      label: _register ? 'Create account' : 'Sign in',
                      onPressed: () async {
                        if (!_form.currentState!.validate()) return;
                        await session.authenticate(
                          email: _email.text,
                          password: _password.text,
                          name: _register ? _name.text : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _register = !_register),
                      child: Text(
                        _register
                            ? 'Already have an account? Sign in'
                            : 'New to Planify? Create an account',
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
