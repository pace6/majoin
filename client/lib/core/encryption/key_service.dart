import 'dart:async';

import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';

import '../client/matrix_client.dart';

/// Wraps Matrix E2EE key management: SSSS recovery key, cross-signing, and
/// online key backup.
///
/// Why this exists: the Matrix SDK encrypts rooms automatically, but without
/// a recovery key + cross-signing the user loses all encrypted history on
/// reinstall and every device shows as unverified. This service drives the
/// SDK [Bootstrap] flow so the UI only deals with "set up" / "restore".
class KeyService {
  KeyService._();
  static final instance = KeyService._();

  Client get _client => MatrixClientService.instance.client;
  Encryption? get _enc => _client.encryption;

  /// E2EE compiled in and enabled for this client.
  bool get encryptionAvailable => _client.encryptionEnabled;

  /// Cross-signing identity exists for this account.
  bool get crossSigningReady => _enc?.crossSigning.enabled ?? false;

  /// Online (server-side) megolm key backup is active.
  bool get keyBackupReady => _enc?.keyManager.enabled ?? false;

  /// An SSSS recovery key/passphrase has been created for this account.
  bool get hasRecovery => _enc?.ssss.defaultKeyId != null;

  /// True once recovery + cross-signing + key backup are all in place.
  bool get fullySetUp => hasRecovery && crossSigningReady && keyBackupReady;

  /// This device has been cross-signed (shows verified to other devices).
  Future<bool> get thisDeviceVerified async {
    final enc = _enc;
    if (enc == null) return false;
    final mine =
        _client.userDeviceKeys[_client.userID]?.deviceKeys[_client.deviceID];
    return mine?.verified ?? false;
  }

  /// Set up E2EE from scratch. Wipes any partial/old state for a deterministic
  /// result, then returns the recovery key — the caller MUST show it to the
  /// user, since losing it means losing encrypted history.
  Future<String> setUp() async {
    final enc = _enc;
    if (enc == null) {
      throw StateError('encryption not available');
    }
    final completer = Completer<String>();
    late final Bootstrap bootstrap;
    bootstrap = enc.bootstrap(onUpdate: (b) async {
      try {
        switch (b.state) {
          case BootstrapState.askWipeSsss:
            b.wipeSsss(true);
          case BootstrapState.askBadSsss:
            b.ignoreBadSecrets(true);
          case BootstrapState.askUseExistingSsss:
            b.useExistingSsss(false);
          case BootstrapState.askNewSsss:
            await b.newSsss();
          case BootstrapState.askWipeCrossSigning:
            await b.wipeCrossSigning(true);
          case BootstrapState.askSetupCrossSigning:
            await b.askSetupCrossSigning(
              setupMasterKey: true,
              setupSelfSigningKey: true,
              setupUserSigningKey: true,
            );
          case BootstrapState.askWipeOnlineKeyBackup:
            b.wipeOnlineKeyBackup(true);
          case BootstrapState.askSetupOnlineKeyBackup:
            await b.askSetupOnlineKeyBackup(true);
          case BootstrapState.error:
            if (!completer.isCompleted) {
              completer.completeError(StateError('bootstrap failed'));
            }
          case BootstrapState.done:
            if (!completer.isCompleted) {
              final key = bootstrap.newSsssKey?.recoveryKey;
              if (key != null) {
                completer.complete(key);
              } else {
                completer.completeError(StateError('no recovery key'));
              }
            }
          default:
            break;
        }
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    });
    return completer.future;
  }

  /// Restore access on this device from an existing recovery key: unlocks
  /// SSSS, self-signs this device via cross-signing, and caches the megolm
  /// backup key so historical room keys load on demand.
  ///
  /// Throws if the recovery key is wrong.
  Future<void> restore(String recoveryKey) async {
    final enc = _enc;
    if (enc == null) {
      throw StateError('encryption not available');
    }
    final key = recoveryKey.trim();
    // selfSign opens + unlocks the cross-signing master key; a wrong key
    // throws here, which is the validation we want.
    await enc.crossSigning.selfSign(recoveryKey: key);
    // Cache every SSSS secret (incl. the online key backup key) locally so
    // the SDK can pull historical room keys when it meets an old event.
    final handle = enc.ssss.open();
    await handle.unlock(recoveryKey: key);
    await handle.maybeCacheAll();
  }

  /// Other devices on this account, newest first. Used by the device list UI.
  List<DeviceKeys> get otherDevices {
    final list = _client.userDeviceKeys[_client.userID]?.deviceKeys.values
        .where((d) => d.deviceId != _client.deviceID)
        .toList();
    return list ?? const [];
  }

  /// Start an interactive (emoji SAS) verification with one of our devices.
  Future<KeyVerification> verifyDevice(DeviceKeys device) =>
      device.startVerification();

  /// Incoming verification requests (e.g. another device wants to verify us).
  Stream<KeyVerification> get incomingVerifications =>
      _client.onKeyVerificationRequest.stream;
}
