import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';

import '../client/matrix_client.dart';
import '../i18n/strings.dart';

/// Pick a gallery image and hand its bytes to [apply]. Returns true on
/// success. Shared by the account-avatar and room-avatar flows.
Future<bool> _pickAvatar(BuildContext context,
    Future<void> Function(MatrixImageFile) apply) async {
  final messenger = ScaffoldMessenger.of(context);
  final XFile? x;
  try {
    x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 800,
      maxHeight: 800,
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('${'pickerError'.tr}: $e')));
    return false;
  }
  if (x == null) return false;
  try {
    final bytes = await File(x.path).readAsBytes();
    await apply(MatrixImageFile(bytes: bytes, name: x.name));
    return true;
  } catch (e) {
    messenger.showSnackBar(
        SnackBar(content: Text('${'profile.avatarError'.tr}: $e')));
    return false;
  }
}

/// Pick an image and set it as the account avatar.
/// Returns true if a new avatar was uploaded.
Future<bool> pickAndSetAvatar(BuildContext context) => _pickAvatar(
    context, (f) => MatrixClientService.instance.client.setAvatar(f));

/// Pick an image and set it as [room]'s avatar.
Future<bool> pickAndSetRoomAvatar(BuildContext context, Room room) =>
    _pickAvatar(context, room.setAvatar);
