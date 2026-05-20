import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';

import '../client/matrix_client.dart';
import '../i18n/strings.dart';

/// Pick an image and set it as the account avatar.
/// Returns true if a new avatar was uploaded — callers should then reload
/// their profile to show it.
Future<bool> pickAndSetAvatar(BuildContext context) async {
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
    await MatrixClientService.instance.client
        .setAvatar(MatrixImageFile(bytes: bytes, name: x.name));
    return true;
  } catch (e) {
    messenger
        .showSnackBar(SnackBar(content: Text('${'profile.avatarError'.tr}: $e')));
    return false;
  }
}
