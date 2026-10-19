import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/session_prefs.dart';
import '../config/supabase_config.dart';
import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/pill_button.dart';
import '../widgets/paw_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _rememberMe = false;
  bool _hidePassword = true;
  bool _loading = false;
  bool _sendingReset = false;

  @override
  void initState() {
    super.initState();
    SessionPrefs.getRememberMe().then((value) {
      if (mounted) setState(() => _rememberMe = value);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  String? _validateEmail(String? v) {
    final email = v?.trim() ?? '';
    if (email.isEmpty) return 'Please enter your email address';
    if (!_isValidEmail(email)) return 'Please enter a valid email address';
    return null;
  }

  String? _validatePassword(String? v) =>
      (v == null || v.isEmpty) ? 'Please enter your password' : null;

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final response = await supabase.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final user = response.user;
      if (user == null) throw const AuthException('Login failed');

      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('owner_id', user.id)
          .maybeSingle();
      final role = ((profile?['role'] as String?) ?? 'client').toLowerCase();
      if (role != 'client') {
        await supabase.auth.signOut();
        _showMessage(
            'Staff accounts must log in through the clinic web application.');
        return;
      }

      await SessionPrefs.setRememberMe(_rememberMe);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, Routes.home, (_) => false);
    } on AuthException catch (e) {
      _showMessage(_friendlyAuthError(e.message));
    } catch (_) {
      _showMessage(
          'Could not log in. Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (m.contains('email not confirmed')) {
      return 'Please confirm your email first. Check your inbox for the link.';
    }
    return message;
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!_isValidEmail(email)) {
      _showMessage('Enter your email address above, then tap Forgot Password.');
      return;
    }

    setState(() => _sendingReset = true);
    try {
      await supabase.auth.resetPasswordForEmail(email);
      _showMessage(
          'If an account exists for $email, a reset link has been sent.',
          success: true);
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not send the reset email. Try again later.');
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.navy : AppColors.red,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PawBackground(
        seed: 3,
        child: SafeArea(
          bottom: false,
          // A plain scrolling page: the picture follows straight after the form,
          // so there is no big empty gap on tall phones.
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 28),
                Text(
                  'Welcome Back!',
                  textAlign: TextAlign.center,
                  style: AppTheme.heading(size: 34)
                      .copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Login to continue caring for your pets',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                _form(),
                const SizedBox(
                    height: 8), // gap between "Register" and the picture
                _pets(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Image.asset('assets/images/logo.png', width: 140),
        ),
        if (Navigator.canPop(context))
          Positioned(
            left: 4,
            top: 4,
            child: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: AppColors.textDark),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
      ],
    );
  }

  Widget _form() {
    final small = Theme.of(context).textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            children: [
              AppTextField(
                controller: _email,
                hint: 'Email Address',
                icon: Icons.mark_email_read_outlined,
                validator: _validateEmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _password,
                hint: 'Password',
                icon: Icons.lock_open,
                validator: _validatePassword,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _login(),
                suffix: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                      _hidePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: AppColors.navy,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? false),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Text('Remember me', style: small),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _sendingReset ? null : _forgotPassword,
                    style: TextButton.styleFrom(foregroundColor: AppColors.red),
                    child:
                        Text(_sendingReset ? 'Sending...' : 'Forgot Password'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: PillButton(
                  label: 'Log in',
                  color: AppColors.red,
                  height: 48,
                  loading: _loading,
                  onPressed: _login,
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, Routes.register),
                child: const Text("Don't have an account? Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pets() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ExcludeSemantics(
        child: Image.asset('assets/images/pets.png', height: 140),
      ),
    );
  }
}
