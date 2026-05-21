import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import '../stickers/pebble_stickers.dart';
import '../../core/i18n/strings.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/pebble_icon.dart';
import 'timeline_state.dart';
import 'voice_recorder.dart';

/// Which inline tray is open above the composer input.
enum _Tray { none, attach, sticker }

class Composer extends StatefulWidget {
  const Composer({super.key, required this.room, required this.ui});
  final Room room;
  final TimelineUiState ui;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _ctl = TextEditingController();
  final _focus = FocusNode();
  bool _canSend = false;
  bool _recording = false;
  _Tray _tray = _Tray.none;

  // Typing notification: refreshed every [_typingRefresh] while text present,
  // each refresh extends the server-side timeout so peers keep seeing it.
  static const _typingTimeout = Duration(seconds: 12);
  static const _typingRefresh = Duration(seconds: 8);
  bool _typingSent = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _ctl.addListener(() {
      final v = _ctl.text.trim().isNotEmpty;
      if (v != _canSend) setState(() => _canSend = v);
      _updateTyping(v);
    });
    widget.ui.addListener(_onUiChange);
    // Typing in the field dismisses any open tray.
    _focus.addListener(() {
      if (_focus.hasFocus && _tray != _Tray.none) {
        setState(() => _tray = _Tray.none);
      }
    });
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
    _focus.dispose();
    _ctl.dispose();
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

  /// Handle a tap on an attach-tray tile.
  Future<void> _onAttachPick(String kind) async {
    setState(() => _tray = _Tray.none);
    switch (kind) {
      case 'camera':
        await _openCamera();
      case 'photo':
        await _pickAndSendPhoto(ImageSource.gallery);
      case 'video':
        await _pickAndSendVideo(ImageSource.gallery);
    }
  }

  /// Camera tile — pick photo or video, then open the OS camera.
  Future<void> _openCamera() async {
    final shoot = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const PebbleIcon(PIcon.camera),
              title: Text('composer.takePhoto'.tr),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const PebbleIcon(PIcon.film),
              title: Text('composer.recordVideo'.tr),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    if (shoot == 'photo') {
      await _pickAndSendPhoto(ImageSource.camera);
    } else if (shoot == 'video') {
      await _pickAndSendVideo(ImageSource.camera);
    }
  }

  /// Rasterize a Pebble sticker to a PNG and send it as an image.
  Future<void> _sendPebbleSticker(PebbleStickerSpec spec) async {
    setState(() => _tray = _Tray.none);
    try {
      final png = await renderPebbleStickerPng(spec);
      await widget.room.sendFileEvent(
        MatrixImageFile(
            bytes: png, name: 'sticker.png', mimeType: 'image/png'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'pickerError'.tr}: $e')),
        );
      }
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
          color: AppTheme.bg,
          border:
              Border(top: BorderSide(color: AppTheme.dividerColor, width: 0.5)),
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
            // Inline trays slide in above the input row.
            if (_tray == _Tray.attach)
              _AttachTray(onPick: _onAttachPick)
            else if (_tray == _Tray.sticker)
              PebbleStickerPanel(onPick: _sendPebbleSticker),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Attach — toggles the inline attach tray.
                  _CircleButton(
                    icon: _tray == _Tray.attach ? PIcon.close : PIcon.plus,
                    bg: _tray == _Tray.attach
                        ? AppTheme.accent
                        : const Color(0x0D000000),
                    fg: _tray == _Tray.attach
                        ? Colors.white
                        : AppTheme.subtleText,
                    onTap: () => setState(() => _tray =
                        _tray == _Tray.attach ? _Tray.none : _Tray.attach),
                    tooltip: 'composer.attach'.tr,
                  ),
                  const SizedBox(width: 8),
                  // Input pill with the sticker button inside.
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.dividerColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Focus(
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent &&
                                    event.logicalKey ==
                                        LogicalKeyboardKey.enter &&
                                    !HardwareKeyboard
                                        .instance.isShiftPressed) {
                                  if (_canSend) _sendText();
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: TextField(
                                controller: _ctl,
                                focusNode: _focus,
                                minLines: 1,
                                maxLines: 5,
                                textInputAction: TextInputAction.newline,
                                style: const TextStyle(fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'composer.hint'.tr,
                                  hintStyle: const TextStyle(
                                      color: AppTheme.subtleText),
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.fromLTRB(
                                      14, 10, 4, 10),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: PebbleIcon(PIcon.smile,
                                size: 22,
                                color: _tray == _Tray.sticker
                                    ? AppTheme.accent
                                    : AppTheme.subtleText),
                            onPressed: () => setState(() => _tray =
                                _tray == _Tray.sticker
                                    ? _Tray.none
                                    : _Tray.sticker),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send when there's text, otherwise voice-record.
                  _canSend
                      ? _CircleButton(
                          icon: PIcon.send,
                          bg: AppTheme.accent,
                          fg: Colors.white,
                          onTap: _sendText,
                        )
                      : _CircleButton(
                          icon: PIcon.mic,
                          bg: const Color(0x0D000000),
                          fg: AppTheme.subtleText,
                          onTap: () => setState(() => _recording = true),
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

/// Inline attach tray — camera / photo / video / audio tiles.
class _AttachTray extends StatelessWidget {
  const _AttachTray({required this.onPick});
  final void Function(String kind) onPick;

  // Voice messages have the dedicated mic button in the composer, so the
  // tray is just camera / photo / video.
  static const _items = <(String, PIcon, Color, String)>[
    ('camera', PIcon.camera, Color(0xFF22B07D), 'attach.camera'),
    ('photo', PIcon.image, Color(0xFF3A6FF0), 'attach.photo'),
    ('video', PIcon.film, Color(0xFFE86A5C), 'attach.video'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0x06000000),
        border: Border(
            top: BorderSide(color: AppTheme.dividerColor, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final (kind, icon, tint, label) in _items)
            InkWell(
              onTap: () => onPick(kind),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 10,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: PebbleIcon(icon, size: 22, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(label.tr,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.ink)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Round 40px composer button (attach / send / mic).
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.tooltip,
  });
  final PIcon icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: PebbleIcon(icon, size: 20, color: fg),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
