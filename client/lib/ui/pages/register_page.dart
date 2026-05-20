import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/auth/register_controller.dart';
import '../../core/config.dart';
import '../../core/i18n/strings.dart';
import '../../core/storage/prefs.dart';
import '../theme/app_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  String? _localError;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RegisterController>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.ink,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'register.title'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _field(_user, 'login.username'.tr,
                              icon: Icons.person_outline),
                          const SizedBox(height: 12),
                          _field(_pass, 'login.password'.tr,
                              icon: Icons.lock_outline, obscure: true),
                          const SizedBox(height: 12),
                          _field(_pass2, 'register.passwordConfirm'.tr,
                              icon: Icons.lock_outline, obscure: true),
                          const SizedBox(height: 8),
                          _serverLabel(),
                          const SizedBox(height: 12),
                          if (_localError != null || ctrl.error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _localError ?? ctrl.error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12),
                              ),
                            ),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.lineGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: ctrl.busy ? null : _submit,
                              child: ctrl.busy
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : Text('register.create'.tr,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (_pass.text.length < 8) {
      setState(() => _localError = 'register.passwordTooShort'.tr);
      return;
    }
    if (_pass.text != _pass2.text) {
      setState(() => _localError = 'register.passwordMismatch'.tr);
      return;
    }
    final ctrl = context.read<RegisterController>();
    final ok = await ctrl.submit(
      homeserver: AppConfig.homeserver,
      user: _user.text.trim(),
      password: _pass.text,
    );
    if (ok && mounted) {
      await Prefs.setLastUser(_user.text.trim());
      if (context.mounted) context.go('/rooms');
    }
  }

  Widget _serverLabel() {
    final host = Uri.parse(AppConfig.homeserver).host;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Icon(Icons.cloud_outlined, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          Text(host,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {IconData? icon, bool obscure = false}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        isDense: true,
      ),
    );
  }
}
