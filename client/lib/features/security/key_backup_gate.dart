import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/client/matrix_client.dart';
import '../../core/encryption/key_service.dart';
import '../../core/i18n/strings.dart';

/// Runs once after login: ensures the account has an encryption key backup
/// and that this device has restored from it. Without this prompt users
/// silently lose access to encrypted history on every reinstall.
///
/// - No backup yet  -> offer to set one up (also covers a fresh register).
/// - Backup exists, this device not verified -> offer to restore from it.
/// - Backup exists and device verified -> nothing to do.
Future<void> maybePromptKeyBackup(BuildContext context) async {
  final ks = KeyService.instance;
  if (!ks.encryptionAvailable) return;

  final client = MatrixClientService.instance.client;
  // SSSS / key-backup state is only reliable after the first sync.
  if (client.prevBatch == null) {
    await client.onSync.stream.first;
  }
  if (!context.mounted) return;

  final verified = await ks.thisDeviceVerified;
  if (ks.hasRecovery && verified) return; // already fully set up here
  if (!context.mounted) return;

  if (ks.hasRecovery) {
    await _promptRestore(context);
  } else {
    await _promptSetup(context);
  }
}

/// No backup on the account — offer to create one now.
Future<void> _promptSetup(BuildContext context) async {
  final go = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('keyBackup.setupTitle'.tr),
      content: Text('keyBackup.setupBody'.tr),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('keyBackup.later'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('keyBackup.setUpNow'.tr),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;

  _showProgress(context);
  String? recoveryKey;
  String? error;
  try {
    recoveryKey = await KeyService.instance.setUp();
  } catch (e) {
    error = e.toString();
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // dismiss progress

  if (recoveryKey != null) {
    await _showRecoveryKey(context, recoveryKey);
  } else {
    _snack(context, '${'keyBackup.setupFailed'.tr}: $error');
  }
}

/// Backup exists but this device has not restored from it yet.
Future<void> _promptRestore(BuildContext context) async {
  final ctl = TextEditingController();
  final key = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('keyBackup.restoreTitle'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('keyBackup.restoreBody'.tr),
          const SizedBox(height: 12),
          TextField(
            controller: ctl,
            autofocus: true,
            minLines: 1,
            maxLines: 3,
            decoration:
                InputDecoration(hintText: 'security.recoveryKeyHint'.tr),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('keyBackup.later'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(ctl.text.trim()),
          child: Text('security.restore'.tr),
        ),
      ],
    ),
  );
  if (key == null || key.isEmpty || !context.mounted) return;

  _showProgress(context);
  String? error;
  try {
    await KeyService.instance.restore(key);
  } catch (e) {
    error = e.toString();
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // dismiss progress

  if (error == null) {
    _snack(context, 'security.restored'.tr);
  } else {
    _snack(context, '${'security.restoreFailed'.tr}: $error');
  }
}

Future<void> _showRecoveryKey(BuildContext context, String key) {
  return showDialog<void>(
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
            if (ctx.mounted) _snack(ctx, 'security.copied'.tr);
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

void _showProgress(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
