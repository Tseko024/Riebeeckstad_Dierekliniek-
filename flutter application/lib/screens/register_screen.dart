import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/paw_background.dart';
import '../config/supabase_config.dart';
import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/pill_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _phone = TextEditingController();

  bool _agreed = false;
  bool _showAgreeError = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _cleanPhone(String value) => value.replaceAll(RegExp(r'[\s\-()]'), '');

  String? _validateName(String? v) =>
      (v == null || v.trim().length < 2) ? 'Please enter your full name' : null;

  String? _validateEmail(String? v) {
    final email = v?.trim() ?? '';
    if (email.isEmpty) return 'Please enter your email address';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Please enter a password';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateConfirm(String? v) =>
      v != _password.text ? 'Passwords do not match' : null;

  String? _validatePhone(String? v) {
    final phone = _cleanPhone(v ?? '');
    if (phone.isEmpty) return 'Please enter your phone number';
    // South African numbers: 0XX XXX XXXX or +27 XX XXX XXXX
    if (!RegExp(r'^(\+27|0)\d{9}$').hasMatch(phone)) {
      return 'Enter a valid SA number, e.g. 071 234 5678';
    }
    return null;
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState!.validate();
    setState(() => _showAgreeError = !_agreed);
    if (!formValid || !_agreed) return;

    setState(() => _loading = true);
    try {
      final response = await supabase.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {
          'full_name': _name.text.trim(),
          'phone': _cleanPhone(_phone.text),
        },
      );
      if (!mounted) return;

      final identities = response.user?.identities;
      if (identities != null && identities.isEmpty) {
        _showMessage(
            'An account with this email already exists. Please log in.');
        return;
      }

      if (response.session != null) {
        Navigator.pushNamedAndRemoveUntil(context, Routes.home, (_) => false);
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Check your email'),
            content: Text(
              'We sent a confirmation link to ${_email.text.trim()}. '
              'Open it, then log in.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, Routes.login);
      }
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage(
          'Could not register. Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.red));
  }

  void _showTerms() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Terms and Privacy', style: AppTheme.heading(size: 24)),
            const SizedBox(height: 12),
            const Text(
              'Riebeeckstad Dierekliniek uses your name, contact details and your pets\' '
              'information only to manage appointments and veterinary care. Your information '
              'is visible only to you and authorised clinic staff, and is handled in line with '
              'the Protection of Personal Information Act (POPIA). Symptom information helps '
              'staff prepare for your visit; it is not a diagnosis.',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PawBackground(
        seed: 2,
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
                const SizedBox(height: 12),
                Text(
                  'Create Your Account',
                  textAlign: TextAlign.center,
                  style: AppTheme.heading(size: 30),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Join our community and give your pets the best care',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _form(),
                const SizedBox(
                    height: 8), // gap between "Log in" and the picture
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
          padding: const EdgeInsets.only(top: 12),
          child: Image.asset('assets/images/logo.png', width: 120),
        ),
        Positioned(
          left: 4,
          top: 4,
          child: IconButton(
            tooltip: 'Back',
            icon:
                const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
      ],
    );
  }

  Widget _form() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            children: [
              AppTextField(
                controller: _name,
                hint: 'Full Name',
                icon: Icons.person,
                validator: _validateName,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _email,
                hint: 'Email Address',
                icon: Icons.mark_email_read_outlined,
                validator: _validateEmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _password,
                hint: 'Password',
                icon: Icons.lock_open,
                validator: _validatePassword,
                obscureText: _hidePassword,
                autofillHints: const [AutofillHints.newPassword],
                suffix: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                      _hidePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _confirm,
                hint: 'Confirm password',
                icon: Icons.lock_open,
                validator: _validateConfirm,
                obscureText: _hideConfirm,
                suffix: IconButton(
                  tooltip: _hideConfirm ? 'Show password' : 'Hide password',
                  icon: Icon(
                      _hideConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _phone,
                hint: 'Phone number',
                icon: Icons.phone,
                validator: _validatePhone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                onSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 10),
              _termsCheckbox(),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: PillButton(
                  label: 'Register',
                  color: AppColors.red,
                  trailingIcon: Icons.arrow_forward,
                  loading: _loading,
                  onPressed: _register,
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, Routes.login),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _termsCheckbox() {
    final linkStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.red);

    Widget link(String text) => GestureDetector(
          onTap: _showTerms,
          child: Text(text, style: linkStyle),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Checkbox(
                value: _agreed,
                activeColor: AppColors.navy,
                onChanged: (v) => setState(() {
                  _agreed = v ?? false;
                  if (_agreed) _showAgreeError = false;
                }),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Wrap(
                  children: [
                    Text('I agree to the ',
                        style: Theme.of(context).textTheme.bodySmall),
                    link('Terms and Conditions'),
                    Text(' and ', style: Theme.of(context).textTheme.bodySmall),
                    link('Privacy Policy'),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_showAgreeError)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 2),
            child: Text(
              'Please accept the terms to continue',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.red),
            ),
          ),
      ],
    );
  }

  Widget _pets() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ExcludeSemantics(
        child: Image.asset('assets/images/pets.png', height: 120),
      ),
    );
  }
}
