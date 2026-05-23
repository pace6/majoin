import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/i18n/strings.dart';
import '../../core/util/mxid.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/pebble_icon.dart';

/// Camera-driven QR scanner for "add friends". Pops with the resolved mxid
/// (a `@local:server` string) once a frame contains a recognized Matrix
/// share URL or bare mxid.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );

  // Stops repeated `_handle` invocations after the first matching frame,
  // and lets us show "invalid QR" briefly without spamming snackbars while
  // the user keeps the camera pointed at the same code.
  bool _consumed = false;
  DateTime _lastInvalidAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handle(BarcodeCapture cap) {
    if (_consumed) return;
    for (final b in cap.barcodes) {
      final mxid = mxidFromShareUrl(b.rawValue);
      if (mxid != null) {
        _consumed = true;
        Navigator.of(context).pop(mxid);
        return;
      }
    }
    // Throttle invalid-QR feedback so a non-Matrix QR in view doesn't
    // produce a snackbar storm.
    final now = DateTime.now();
    if (now.difference(_lastInvalidAt) > const Duration(seconds: 2)) {
      _lastInvalidAt = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('addFriends.scanInvalid'.tr),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('addFriends.scanTitle'.tr,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 17)),
        leading: IconButton(
          icon: const PebbleIcon(PIcon.back, size: 20, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (_, state, __) => Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
              ),
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handle,
            errorBuilder: (_, err) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  err.errorDetails?.message ?? err.errorCode.toString(),
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          // Dim overlay with a transparent reticle in the middle.
          IgnorePointer(
            child: CustomPaint(
              painter: _ReticlePainter(),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Text(
              'addFriends.scanHint'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a translucent black scrim with a clear square in the centre,
/// outlined by short L-shaped corner brackets in the accent colour.
class _ReticlePainter extends CustomPainter {
  static const double _frameRatio = 0.7; // square side relative to width.

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width * _frameRatio;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );

    // Scrim: full screen minus the reticle hole.
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)));
    canvas.drawPath(
      scrim,
      Paint()..color = Colors.black.withValues(alpha: .55),
    );

    // Corner brackets.
    final stroke = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const armLen = 22.0;
    final r = rect;
    void corner(Offset p, Offset a, Offset b) {
      canvas.drawLine(p, p + a, stroke);
      canvas.drawLine(p, p + b, stroke);
    }
    corner(r.topLeft, const Offset(armLen, 0), const Offset(0, armLen));
    corner(r.topRight, const Offset(-armLen, 0), const Offset(0, armLen));
    corner(r.bottomLeft, const Offset(armLen, 0), const Offset(0, -armLen));
    corner(r.bottomRight, const Offset(-armLen, 0), const Offset(0, -armLen));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
