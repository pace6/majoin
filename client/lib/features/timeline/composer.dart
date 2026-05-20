import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import '../flex/demo_payloads.dart';
import '../flex/send_flex.dart';
import '../stickers/send_sticker.dart';
import '../stickers/sticker_picker.dart';
import '../../core/client/matrix_client.dart';
import '../../core/i18n/strings.dart';
import '../../ui/theme/app_theme.dart';
import 'timeline_state.dart';
import 'voice_recorder.dart';

class Composer extends StatefulWidget {
  const Composer({super.key, required this.room, required this.ui});
  final Room room;
  final TimelineUiState ui;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _ctl = TextEditingController();
  bool _canSend = false;
  bool _recording = false;

  // Typing notification: refreshed every [_typingRefresh] while text present,
  // each refresh extends the server-side timeout so peers keep seeing it.
  static const _typingTimeout = Duration(seconds: 12);
  static const _typingRefresh = Duration(seconds: 8);
  bool _typingSent = false;
  Timer? _typingTimer;

  late final _sticker = StickerSender(MatrixClientService.instance.client);

  @override
  void initState() {
    super.initState();
    _ctl.addListener(() {
      final v = _ctl.text.trim().isNotEmpty;
      if (v != _canSend) setState(() => _canSend = v);
      _updateTyping(v);
    });
    widget.ui.addListener(_onUiChange);
  }

  // Tracks which event the composer is currently editing, so entering edit
  // mode prefills the field once and leaving it clears the field.
  String? _editingId;

  void _onUiChange() {
    final edit = widget.ui.editTarget;
    if (edit != null && edit.eventId != _editingId) {
      _editingId = edit.eventId;
      _ctl.text = edit.body;
      _ctl.selection =
          TextSelection.collapsed(offset: _ctl.text.length);
    } else if (edit == null && _editingId != null) {
      _editingId = null;
      _ctl.clear();
    }
    setState(() {});
  }

  void _updateTyping(bool typing) {
    if (typing) {
      _typingTimer ??= Timer.periodic(_typingRefresh, (_) => _pushTyping(true));
      _pushTyping(true);
    } else {
      _typingTimer?.cancel();
      _typingTimer = null;
      _pushTyping(false);
    }
  }

  void _pushTyping(bool typing) {
    if (typing == false && _typingSent == false) return;
    _typingSent = typing;
    widget.room.setTyping(typing,
        timeout: typing ? _typingTimeout.inMilliseconds : null);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_typingSent) widget.room.setTyping(false);
    widget.ui.removeListener(_onUiChange);
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    _updateTyping(false);
    final edit = widget.ui.editTarget;
    if (edit != null) {
      _ctl.clear();
      widget.ui.clearEdit();
      await widget.room.sendTextEvent(text, editEventId: edit.eventId);
      return;
    }
    _ctl.clear();
    final reply = widget.ui.replyTo;
    widget.ui.clearReply();
    await widget.room.sendTextEvent(text, inReplyTo: reply);
  }

  Future<void> _showAttachSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text('composer.photoGallery'.tr),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text('composer.takePhoto'.tr),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.video_library_outlined),
            title: Text('composer.videoGallery'.tr),
            onTap: () => Navigator.pop(context, 'videoGallery'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: Text('composer.recordVideo'.tr),
            onTap: () => Navigator.pop(context, 'videoCamera'),
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text('composer.file'.tr),
            onTap: () => Navigator.pop(context, 'file'),
          ),
          ListTile(
            leading: const Icon(Icons.emoji_emotions_outlined),
            title: Text('composer.sticker'.tr),
            onTap: () => Navigator.pop(context, 'sticker'),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: Text('composer.flexDemo'.tr),
            onTap: () => Navigator.pop(context, 'flex'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'gallery':
        await _pickAndSendPhoto(ImageSource.gallery);
      case 'camera':
        await _pickAndSendPhoto(ImageSource.camera);
      case 'videoGallery':
        await _pickAndSendVideo(ImageSource.gallery);
      case 'videoCamera':
        await _pickAndSendVideo(ImageSource.camera);
      case 'file':
        await _pickAndSendFile();
      case 'sticker':
        final s = await StickerPickerSheet.show(context);
        if (s != null) await _sticker.send(widget.room, s);
      case 'flex':
        await _pickAndSendFlex();
    }
  }

  // Cap picked images so large camera-roll photos upload fast.
  static const _photoMaxEdge = 1920.0;

  Future<void> _pickAndSendPhoto(ImageSource source) async {
    final picker = ImagePicker();
    // Gallery allows multi-select; camera captures one shot at a time.
    final List<XFile> picked;
    try {
      if (source == ImageSource.gallery) {
        picked = await picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: _photoMaxEdge,
          maxHeight: _photoMaxEdge,
        );
      } else {
        final x = await picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: _photoMaxEdge,
          maxHeight: _photoMaxEdge,
        );
        picked = x == null ? const [] : [x];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'pickerError'.tr}: $e')),
        );
      }
      return;
    }
    if (picked.isEmpty) return;
    // Upload all photos in parallel; timeline order may differ slightly.
    await Future.wait(picked.map((x) async {
      final bytes = await File(x.path).readAsBytes();
      await widget.room.sendFileEvent(
        MatrixImageFile(bytes: bytes, name: x.name),
      );
    }));
  }

  Future<void> _pickAndSendVideo(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? x;
    try {
      x = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'pickerError'.tr}: $e')),
        );
      }
      return;
    }
    if (x == null) return;
    final bytes = await File(x.path).readAsBytes();
    await widget.room.sendFileEvent(
      MatrixVideoFile(bytes: bytes, name: x.name),
    );
  }

  Future<void> _pickAndSendFile() async {
    final FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(withData: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'pickerError'.tr}: $e')),
        );
      }
      return;
    }
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    // withData loads bytes in memory; fall back to reading the path on desktop.
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) return;
    await widget.room.sendFileEvent(MatrixFile(bytes: bytes, name: f.name));
  }

  Future<void> _pickAndSendFlex() async {
    final entries = FlexDemos.all.entries.toList();
    final pick = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < entries.length; i++)
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: Text(entries[i].key),
              onTap: () => Navigator.pop(context, i),
            ),
        ],
      ),
    );
    if (pick == null) return;
    await sendFlex(widget.room, entries[pick].value);
  }

  @override
  Widget build(BuildContext context) {
    final reply = widget.ui.replyTo;
    final editTarget = widget.ui.editTarget;
    if (_recording) {
      return SafeArea(
        top: false,
        child: VoiceRecorderBar(
          room: widget.room,
          onDone: () => setState(() => _recording = false),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEBEBEB), width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (editTarget != null)
              _EditBanner(onClear: () => widget.ui.clearEdit())
            else if (reply != null)
              _ReplyPreview(
                event: reply,
                onClear: () => widget.ui.clearReply(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF666666)),
              onPressed: _showAttachSheet,
              tooltip: 'composer.attach'.tr,
            ),
            IconButton(
              icon: const Icon(Icons.photo_camera_outlined,
                  color: Color(0xFF666666)),
              onPressed: () => _pickAndSendPhoto(ImageSource.camera),
              tooltip: 'composer.takePhoto'.tr,
            ),
            IconButton(
              icon: const Icon(Icons.photo_outlined, color: Color(0xFF666666)),
              onPressed: () => _pickAndSendPhoto(ImageSource.gallery),
              tooltip: 'composer.photoGallery'.tr,
            ),
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter &&
                      !HardwareKeyboard.instance.isShiftPressed) {
                    if (_canSend) _sendText();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                controller: _ctl,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'composer.hint'.tr,
                  hintStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined,
                        size: 22, color: Color(0xFF888888)),
                    onPressed: () async {
                      final s = await StickerPickerSheet.show(context);
                      if (s != null) await _sticker.send(widget.room, s);
                    },
                  ),
                ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _canSend ? Icons.send_rounded : Icons.mic_none,
                color: _canSend ? const Color(0xFF06C755) : const Color(0xFF888888),
              ),
              onPressed: _canSend
                  ? _sendText
                  : () => setState(() => _recording = true),
            ),
          ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner shown above the composer while editing an existing message.
class _EditBanner extends StatelessWidget {
  const _EditBanner({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Container(width: 3, height: 36, color: AppTheme.lineGreen),
          const SizedBox(width: 8),
          const Icon(Icons.edit_outlined,
              size: 16, color: AppTheme.lineGreen),
          const SizedBox(width: 6),
          Expanded(
            child: Text('composer.editing'.tr,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.lineGreen,
                    fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.event, required this.onClear});
  final Event event;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final name = event.senderFromMemoryOrFallback.calcDisplayname();
    final preview = event.type == 'm.sticker'
        ? 'msg.sticker'.tr
        : event.type == 'app.majoin.flex'
            ? 'msg.flex'.tr
            : event.body;
    return Container(
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Container(width: 3, height: 36, color: AppTheme.lineGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${'composer.replyingTo'.tr} $name',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.lineGreen,
                        fontWeight: FontWeight.w600)),
                Text(preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.subtleText)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
