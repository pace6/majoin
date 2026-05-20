import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';

import '../../core/encryption/key_service.dart';
import '../../core/i18n/strings.dart';
import '../../features/security/verification_sheet.dart';

/// Encryption / security settings: recovery key setup, restore, and the list
/// of this account's devices with their verification state.
class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final _ks = KeyService.instance;
  bool _busy = false;

  Future<void> _runSetUp() async {
    setState(() => _busy = true);
    try {
      final recoveryKey = await _ks.setUp();
      if (mounted) await _showRecoveryKey(recoveryKey);
    } catch (e) {
      _snack('${'security.setupFailed'.tr}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRecoveryKey(String key) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('security.recoveryKeyTitle'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('security.recoveryKeyWarning'.tr),
            const SizedBox(height: 12),
            SelectableText(
              key,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 14, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: key));
              _snack('security.copied'.tr);
            },
            child: Text('msg.copy'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('security.savedIt'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _runRestore() async {
    final key = await _promptRecoveryKey();
    if (key == null || key.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _ks.restore(key);
      _snack('security.restored'.tr);
    } catch (e) {
      _snack('${'security.restoreFailed'.tr}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptRecoveryKey() {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('security.enterRecoveryKey'.tr),
        content: TextField(
          controller: ctl,
          autofocus: true,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(hintText: 'security.recoveryKeyHint'.tr),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctl.text.trim()),
            child: Text('security.restore'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _verify(DeviceKeys device) async {
    try {
      final req = await _ks.verifyDevice(device);
      if (mounted) await VerificationSheet.show(context, req);
      if (mounted) setState(() {});
    } catch (e) {
      _snack('${'verify.failed'.tr}: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg.tr == msg ? msg : msg.tr)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('security.title'.tr)),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (!_ks.encryptionAvailable)
                  ListTile(
                    leading: const Icon(Icons.lock_open, color: Colors.red),
                    title: Text('security.unavailable'.tr),
                  )
                else ...[
                  _statusTile(
                    'security.recovery'.tr,
                    _ks.hasRecovery,
                  ),
                  _statusTile(
                    'security.crossSigning'.tr,
                    _ks.crossSigningReady,
                  ),
                  _statusTile(
                    'security.keyBackup'.tr,
                    _ks.keyBackupReady,
                  ),
                  const Divider(),
                  if (!_ks.fullySetUp)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: _runSetUp,
                        icon: const Icon(Icons.enhanced_encryption),
                        label: Text('security.setUp'.tr),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: OutlinedButton.icon(
                      onPressed: _runRestore,
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: Text('security.restore'.tr),
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('security.devices'.tr,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  for (final d in _ks.otherDevices)
                    ListTile(
                      leading: Icon(
                        d.verified ? Icons.verified_user : Icons.devices,
                        color: d.verified
                            ? const Color(0xFF06C755)
                            : Colors.orange,
                      ),
                      title: Text(d.deviceDisplayName ??
                          d.deviceId ??
                          'security.unknownDevice'.tr),
                      subtitle: Text(d.verified
                          ? 'security.verified'.tr
                          : 'security.unverified'.tr),
                      trailing: d.verified
                          ? null
                          : TextButton(
                              onPressed: () => _verify(d),
                              child: Text('security.verify'.tr),
                            ),
                    ),
                  if (_ks.otherDevices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('security.noOtherDevices'.tr,
                          style: const TextStyle(color: Colors.grey)),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _statusTile(String label, bool ok) {
    return ListTile(
      leading: Icon(
        ok ? Icons.check_circle : Icons.cancel,
        color: ok ? const Color(0xFF06C755) : Colors.orange,
      ),
      title: Text(label),
      subtitle: Text(ok ? 'security.on'.tr : 'security.off'.tr),
    );
  }
}
