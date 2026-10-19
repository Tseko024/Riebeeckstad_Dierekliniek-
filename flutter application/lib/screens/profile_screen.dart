import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/session_prefs.dart';
import '../config/supabase_config.dart';
import '../data/profile_repo.dart';
import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_text_field.dart';
import '../widgets/paw_background.dart';
import '../widgets/pill_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  String _email = '';
  int _petCount = 0;
  int _apptCount = 0;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ProfileRepo.myProfile();
      final (pets, appts) = await ProfileRepo.myCounts();
      if (!mounted) return;
      setState(() {
        _name.text = profile.fullName;
        _phone.text = profile.phone ?? '';
        _email = profile.email;
        _petCount = pets;
        _apptCount = appts;
      });
    } catch (e) {
      debugPrint('Load profile error: $e');
      if (mounted) setState(() => _error = 'Could not load your profile.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cleanPhone(String value) => value.replaceAll(RegExp(r'[\s\-()]'), '');

  String? _validateName(String? v) =>
      (v == null || v.trim().length < 2) ? 'Please enter your full name' : null;

  String? _validatePhone(String? v) {
    final phone = _cleanPhone(v ?? '');
    if (phone.isEmpty) return 'Please enter your phone number';
    if (!RegExp(r'^(\+27|0)\d{9}$').hasMatch(phone)) {
      return 'Enter a valid SA number, e.g. 071 234 5678';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await ProfileRepo.updateProfile(
        fullName: _name.text.trim(),
        phone: _cleanPhone(_phone.text),
      );
      _snack('Your details have been saved.', success: true);
    } on PostgrestException catch (e) {
      _snack(e.message);
    } catch (e) {
      debugPrint('Save profile error: $e');
      _snack('Could not save. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true) _snack('Password changed.', success: true);
  }

  Future<void> _logout() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {}
    await SessionPrefs.setRememberMe(false);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.welcome, (_) => false);
  }

  void _snack(String text, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: success ? AppColors.navy : AppColors.red,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Image.asset('assets/images/logo.png', height: 56),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: Routes.profile),
      body: PawBackground(
        seed: 12,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        TextButton(
                            onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  )
                : _content(),
      ),
    );
  }

  Widget _content() {
    final text = Theme.of(context).textTheme;
    final initials = _name.text.trim().isEmpty
        ? '?'
        : _name.text
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text('My Profile',
            style: AppTheme.heading(size: 30)
                .copyWith(fontStyle: FontStyle.italic)),
        const Text('Manage your account details'),
        const SizedBox(height: 20),

        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.navy,
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name.text.isEmpty ? 'Pet owner' : _name.text,
                        style: AppTheme.heading(size: 22),
                        overflow: TextOverflow.ellipsis),
                    Text(_email,
                        style: text.bodySmall, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _countChip(
                            Icons.pets,
                            '$_petCount pet${_petCount == 1 ? '' : 's'}',
                            () => Navigator.pushNamed(context, Routes.pets)),
                        _countChip(
                            Icons.event_note,
                            '$_apptCount appointment${_apptCount == 1 ? '' : 's'}',
                            () => Navigator.pushNamed(
                                context, Routes.appointments)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Editable details
        Text('Your details',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                controller: _name,
                hint: 'Full Name',
                icon: Icons.person,
                validator: _validateName,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _phone,
                hint: 'Phone number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                validator: _validatePhone,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 12),
              // Email is shown but not editable here
              TextFormField(
                initialValue: _email,
                enabled: false,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.mark_email_read_outlined),
                  helperText:
                      'Email can\'t be changed in the app. Contact the clinic if needed.',
                  filled: true,
                  fillColor: Colors.white70,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: PillButton(
                    label: 'Save Changes',
                    color: AppColors.navy,
                    icon: Icons.save,
                    trailingIcon: Icons.check,
                    loading: _saving,
                    onPressed: _save,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text('Account',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Card(
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_reset, color: AppColors.navy),
                title: const Text('Change password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _changePassword,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined,
                    color: AppColors.navy),
                title: const Text('Privacy'),
                subtitle: const Text(
                    'Your information is only visible to you and clinic staff.'),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Your privacy'),
                    content: const Text(
                      'Riebeeckstad Dierekliniek uses your name, contact details and your pets\' '
                      'information only to manage appointments and veterinary care. Your information '
                      'is visible only to you and authorised clinic staff, and is handled in line with '
                      'the Protection of Personal Information Act (POPIA).',
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK')),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.red),
                title: const Text('Log out',
                    style: TextStyle(color: AppColors.red)),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _countChip(IconData icon, String label, VoidCallback onTap) =>
      ActionChip(
        avatar: Icon(icon, size: 16, color: AppColors.navy),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        backgroundColor: AppColors.background,
        onPressed: onTap,
      );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await supabase.auth.updateUser(UserAttributes(password: _password.text));
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not change the password. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _password,
              obscureText: _hide,
              decoration: InputDecoration(
                labelText: 'New password',
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 8) ? 'At least 8 characters' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirm,
              obscureText: _hide,
              decoration:
                  const InputDecoration(labelText: 'Confirm new password'),
              validator: (v) =>
                  v != _password.text ? 'Passwords do not match' : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child:
                    Text(_error!, style: const TextStyle(color: AppColors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Saving...' : 'Change'),
        ),
      ],
    );
  }
}
