import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../theme/app_theme.dart';

/// Pebble welcome screen — logo hero + sign-in / create-account buttons.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo hero in a soft accent halo.
                    Container(
                      width: 220,
                      height: 220,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [AppTheme.accentSoft, AppTheme.bg],
                          radius: 0.7,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3322B07D),
                              blurRadius: 22,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text('M',
                            style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('app.name'.tr,
                        style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.4,
                            color: AppTheme.ink)),
                    const SizedBox(height: 8),
                    Text('welcome.tagline'.tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: AppTheme.subtleText)),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () => context.push('/login'),
                  child: Text('login.signIn'.tr,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.ink,
                    side: const BorderSide(color: AppTheme.dividerColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () => context.push('/register'),
                  child: Text('register.title'.tr,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 14),
              Text('welcome.terms'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppTheme.subtleText)),
            ],
          ),
        ),
      ),
    );
  }
}
