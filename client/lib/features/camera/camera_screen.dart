import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';

/// Result of the in-app camera: a captured file and whether it's a video.
class CameraResult {
  const CameraResult(this.path, {required this.isVideo});
  final String path;
  final bool isVideo;
}

/// LINE-style in-app camera — live viewfinder, tap the shutter for a photo,
/// hold it to record a video. Pops a [CameraResult].
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  List<CameraDescription> _cameras = const [];
  int _index = 0;
  CameraController? _ctl;
  bool _recording = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'camera.unavailable');
        return;
      }
      await _start(0);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _start(int index) async {
    final old = _ctl;
    final c = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
    );
    await c.initialize();
    await old?.dispose();
    if (mounted) {
      setState(() {
        _ctl = c;
        _index = index;
      });
    } else {
      await c.dispose();
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _recording) return;
    await _start((_index + 1) % _cameras.length);
  }

  Future<void> _takePhoto() async {
    final c = _ctl;
    if (c == null || _recording || c.value.isTakingPicture) return;
    try {
      final file = await c.takePicture();
      if (mounted) {
        Navigator.of(context).pop(CameraResult(file.path, isVideo: false));
      }
    } catch (_) {}
  }

  Future<void> _startVideo() async {
    final c = _ctl;
    if (c == null || _recording) return;
    try {
      await c.startVideoRecording();
      if (mounted) setState(() => _recording = true);
    } catch (_) {}
  }

  Future<void> _stopVideo() async {
    final c = _ctl;
    if (c == null || !_recording) return;
    try {
      final file = await c.stopVideoRecording();
      if (mounted) {
        setState(() => _recording = false);
        Navigator.of(context).pop(CameraResult(file.path, isVideo: true));
      }
    } catch (_) {
      if (mounted) setState(() => _recording = false);
    }
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Viewfinder.
          Positioned.fill(
            child: _error != null
                ? Center(
                    child: Text('camera.unavailable'.tr,
                        style: const TextStyle(color: Colors.white70)))
                : c == null
                    ? const Center(child: CircularProgressIndicator())
                    : FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: c.value.previewSize?.height ?? 1,
                          height: c.value.previewSize?.width ?? 1,
                          child: CameraPreview(c),
                        ),
                      ),
          ),
          // Close.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          // Recording dot.
          if (_recording)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('camera.recording'.tr,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          // Controls.
          if (c != null && _error == null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('camera.hint'.tr,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 64),
                          // Shutter — tap = photo, hold = video.
                          GestureDetector(
                            onTap: _takePhoto,
                            onLongPressStart: (_) => _startVideo(),
                            onLongPressEnd: (_) => _stopVideo(),
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 4),
                                color: _recording
                                    ? const Color(0xFFFF3B30)
                                    : Colors.white24,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 64,
                            child: IconButton(
                              icon: const Icon(Icons.flip_camera_ios,
                                  color: Colors.white, size: 28),
                              onPressed: _flip,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
