import 'package:flutter/material.dart';
import 'package:matrix/encryption.dart';

import '../../core/i18n/strings.dart';

/// Modal that drives an emoji-SAS key verification to completion.
///
/// Works for both directions: a request we started (already past `askAccept`)
/// and an incoming request (starts at `askAccept`, user accepts here).
class VerificationSheet extends StatefulWidget {
  const VerificationSheet({super.key, required this.request});

  final KeyVerification request;

  /// Show as a modal bottom sheet. Not dismissible by tap-outside so a
  /// half-finished verification can't be silently abandoned.
  static Future<void> show(BuildContext context, KeyVerification request) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      showDragHandle: true,
      builder: (_) => VerificationSheet(request: request),
    );
  }

  @override
  State<VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<VerificationSheet> {
  @override
  void initState() {
    super.initState();
    widget.request.onUpdate = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    widget.request.onUpdate = null;
    super.dispose();
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('verify.title'.tr,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ..._bodyFor(req),
          ],
        ),
      ),
    );
  }

  List<Widget> _bodyFor(KeyVerification req) {
    switch (req.state) {
      case KeyVerificationState.askAccept:
      case KeyVerificationState.askChoice:
        return [
          Text('verify.incoming'.tr, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await req.rejectVerification();
                    _close();
                  },
                  child: Text('verify.reject'.tr),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => req.acceptVerification(),
                  child: Text('verify.accept'.tr),
                ),
              ),
            ],
          ),
        ];
      case KeyVerificationState.askSas:
        return [
          Text('verify.compareEmoji'.tr, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final e in req.sasEmojis)
                SizedBox(
                  width: 64,
                  child: Column(
                    children: [
                      Text(e.emoji, style: const TextStyle(fontSize: 32)),
                      Text(e.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => req.rejectSas(),
                  child: Text('verify.noMatch'.tr),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => req.acceptSas(),
                  child: Text('verify.match'.tr),
                ),
              ),
            ],
          ),
        ];
      case KeyVerificationState.done:
        return [
          const Icon(Icons.verified_user, color: Color(0xFF06C755), size: 48),
          const SizedBox(height: 12),
          Text('verify.done'.tr),
          const SizedBox(height: 16),
          FilledButton(onPressed: _close, child: Text('common.ok'.tr)),
        ];
      case KeyVerificationState.error:
        return [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text('verify.failed'.tr),
          const SizedBox(height: 16),
          FilledButton(onPressed: _close, child: Text('common.ok'.tr)),
        ];
      default:
        return [
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
          Text('verify.waiting'.tr),
        ];
    }
  }
}
