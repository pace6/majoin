import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/strings.dart';

/// Entry sheet — a LINE-style "Create" grid (Chat / Group / Meeting) that
/// slides down from the top. Returns the new/reused room id on success.
Future<String?> showNewChatDialog(BuildContext context) async {
  final mode = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel:
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (sheetCtx, _, _) => Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Theme.of(sheetCtx).colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header — centered title, close button on the left.
                SizedBox(
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text('newChat.title'.tr,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _CreateOption(
                          icon: Icons.chat_bubble_outline,
                          label: 'newChat.optChat'.tr,
                          onTap: () => Navigator.pop(sheetCtx, 'dm'),
                        ),
                      ),
                      Expanded(
                        child: _CreateOption(
                          icon: Icons.group_add_outlined,
                          label: 'newChat.optGroup'.tr,
                          onTap: () => Navigator.pop(sheetCtx, 'group'),
                        ),
                      ),
                      // Meeting (group call) isn't implemented yet — shown
                      // disabled as a placeholder.
                      Expanded(
                        child: _CreateOption(
                          icon: Icons.video_call_outlined,
                          label: 'newChat.optMeeting'.tr,
                          onTap: null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, anim, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
  if (mode == null || !context.mounted) return null;
  // Both flows are full slide-in screens, for a consistent look.
  // Add-friends navigates into the chat itself, so it pops no room id.
  if (mode == 'dm') return context.push<String>('/add-friends');
  return context.push<String>('/create-group');
}

/// One icon-in-rounded-square option in the "Create" grid.
class _CreateOption extends StatelessWidget {
  const _CreateOption({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).disabledColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(
                    color: enabled
                        ? const Color(0x33000000)
                        : const Color(0x14000000),
                    width: 1.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 26, color: fg),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: fg)),
          ],
        ),
      ),
    );
  }
}
