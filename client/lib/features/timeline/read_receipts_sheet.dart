import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';

import '../../core/client/matrix_client.dart';
import '../../core/i18n/strings.dart';
import '../../core/util/mxid.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/mxc_image.dart';

/// Bottom sheet listing who has read [event] (its read receipts).
Future<void> showReadReceiptsSheet(BuildContext context, Event event) async {
  final myId = MatrixClientService.instance.client.userID;
  final receipts = event.receipts
      .where((r) => r.user.id != myId)
      .toList()
    ..sort((a, b) => b.time.compareTo(a.time));

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${'readBy.title'.tr} (${receipts.length})',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (receipts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Text('readBy.none'.tr,
                  style: const TextStyle(color: AppTheme.subtleText)),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [for (final r in receipts) _ReceiptTile(receipt: r)],
              ),
            ),
        ],
      ),
    ),
  );
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.receipt});
  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final name = receipt.user.calcDisplayname();
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final mxc = receipt.user.avatarUrl?.toString();
    return ListTile(
      leading: ClipOval(
        child: SizedBox(
          width: 42,
          height: 42,
          child: mxc != null && mxc.isNotEmpty
              ? MxcImage(url: mxc, width: 42, height: 42)
              : Container(
                  color: AppTheme.accentSoft,
                  alignment: Alignment.center,
                  child: Text(letter,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentDeep)),
                ),
        ),
      ),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text('@${localpartOf(receipt.user.id)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              const TextStyle(fontSize: 12.5, color: AppTheme.subtleText)),
      trailing: Text(DateFormat.Hm().format(receipt.time),
          style: const TextStyle(fontSize: 12, color: AppTheme.subtleText)),
    );
  }
}
