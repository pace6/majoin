import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import 'user_directory.dart';

/// Add Friends — the registered-user directory presented as a full screen.
/// Search + "Friends"/"Others" sections come from [UserDirectory].
class AddFriendsScreen extends StatelessWidget {
  const AddFriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text('addFriends.title'.tr,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: const SafeArea(child: UserDirectory()),
    );
  }
}
