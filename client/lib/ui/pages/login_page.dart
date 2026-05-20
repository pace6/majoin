import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/auth/login_controller.dart';
import '../../core/config.dart';
import '../../core/i18n/strings.dart';
import '../../core/storage/prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/pebble_icon.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();

  @override
  void initState() {
    super.initState();
    Prefs.lastUser().then((v) {
      if (v != null && mounted) _user.text = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LoginController>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
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
                  const SizedBox(height: 40),
                  // Logo mark
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x2222B07D),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 110),
                    child: const Center(
                      child: Text(
                        'M',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'login.title'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    'app.tagline'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.subtleText),
                  ),
                  const SizedBox(height: 40),
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _field(_user, 'login.username'.tr,
                              icon: PIcon.person),
                          const SizedBox(height: 12),
                          _field(_pass, 'login.password'.tr,
                              icon: PIcon.lock, obscure: true),
                          const SizedBox(height: 8),
                          _serverLabel(),
                          const SizedBox(height: 12),
                          if (ctrl.error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                ctrl.error!,
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
                              onPressed: ctrl.busy
                                  ? null
                                  : () async {
                                      final ok = await ctrl.submit(
                                        homeserver: AppConfig.homeserver,
                                        user: _user.text.trim(),
                                        password: _pass.text,
                                      );
                                      if (ok && mounted) {
                                        await Prefs.setLastUser(
                                            _user.text.trim());
                                        if (context.mounted) {
                                          context.go('/rooms');
                                        }
                                      }
                                    },
                              child: ctrl.busy
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : Text('login.signIn'.tr,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('login.noAccount'.tr,
                          style: const TextStyle(color: AppTheme.subtleText)),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: Text('login.createOne'.tr,
                            style: const TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _serverLabel() {
    final host = Uri.parse(AppConfig.homeserver).host;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const PebbleIcon(PIcon.globe, size: 14, color: AppTheme.subtleText),
          const SizedBox(width: 6),
          Text(host,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {PIcon? icon, bool obscure = false}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : PebbleIcon(icon, size: 20),
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
