import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/theme/app_colors.dart';
import '../../core/enrollment/enrollment_models.dart';
import '../../core/services/app_services.dart';
import 'enrollment_review_screen.dart';

class EnrollmentScannerScreen extends StatefulWidget {
  const EnrollmentScannerScreen({super.key});

  @override
  State<EnrollmentScannerScreen> createState() =>
      _EnrollmentScannerScreenState();
}

class _EnrollmentScannerScreenState extends State<EnrollmentScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  late final AnimationController _pulseController;
  bool _processing = false;
  bool _captured = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      lowerBound: .35,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_processing || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.trim().isEmpty) return;
    await _processPayload(value);
  }

  Future<void> _processPayload(String payload) async {
	final enrollment = AppServices.of(context).enrollment;
    setState(() {
      _processing = true;
      _captured = false;
      _error = null;
    });
    await _controller.stop();

    try {
      final invitation = await enrollment.parseInvitation(payload);
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => _captured = true);
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => EnrollmentReviewScreen(invitation: invitation),
        ),
      );
    } on EnrollmentException catch (error) {
      await HapticFeedback.vibrate();
      if (!mounted) return;
      setState(() {
        _processing = false;
        _captured = false;
        _error = error.message;
      });
      await _controller.start();
    } on Object catch (error) {
      await HapticFeedback.vibrate();
      if (!mounted) return;
      setState(() {
        _processing = false;
        _captured = false;
        _error = 'Unable to read this enrollment code: $error';
      });
      await _controller.start();
    }
  }

  Future<void> _openManualEntry() async {
    final controller = TextEditingController();
    final payload = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter enrollment payload'),
        content: TextField(
          controller: controller,
          minLines: 5,
          maxLines: 10,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            hintText: 'Paste the JSON enrollment payload',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Validate'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (payload != null && payload.trim().isNotEmpty) {
      await _processPayload(payload);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frameColor = _captured ? AppColors.success : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enroll Device'),
        actions: [
          Semantics(
            button: true,
            label: 'Toggle camera flashlight',
            child: IconButton(
              tooltip: 'Toggle flashlight',
              onPressed: _processing ? null : _controller.toggleTorch,
              icon: const Icon(Icons.flashlight_on_outlined),
            ),
          ),
          Semantics(
            button: true,
            label: 'Switch between front and rear cameras',
            child: IconButton(
              tooltip: 'Switch camera',
              onPressed: _processing ? null : _controller.switchCamera,
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _handleCapture),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) => _ScannerOverlay(
              color: frameColor,
              glowOpacity: _captured ? 1 : _pulseController.value,
              captured: _captured,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: .96),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 28,
                          offset: Offset(0, 12),
                          color: Color(0x66000000),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Row(
                              key: ValueKey<String>(
                                _captured
                                    ? 'captured'
                                    : _processing
                                    ? 'processing'
                                    : 'ready',
                              ),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_captured) ...[
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    _captured
                                        ? 'Enrollment code captured'
                                        : _processing
                                        ? 'Validating enrollment code…'
                                        : 'Position the enrollment QR code inside the frame.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_processing && !_captured) ...[
                            const SizedBox(height: 14),
                            const LinearProgressIndicator(),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _processing ? null : _openManualEntry,
                            icon: const Icon(Icons.content_paste_outlined),
                            label: const Text('Enter enrollment code manually'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pr0jectZer0 Auth  •  The Bostrom Group',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final Color color;
  final double glowOpacity;
  final bool captured;

  const _ScannerOverlay({
    required this.color,
    required this.glowOpacity,
    required this.captured,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        label: captured
            ? 'Enrollment QR code captured'
            : 'Enrollment QR scanning frame',
        child: CustomPaint(
          painter: _ScannerOverlayPainter(
            color: color,
            glowOpacity: glowOpacity,
            captured: captured,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color color;
  final double glowOpacity;
  final bool captured;

  const _ScannerOverlayPainter({
    required this.color,
    required this.glowOpacity,
    required this.captured,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frameSize = size.shortestSide.clamp(250.0, 290.0);
    final center = Offset(size.width / 2, size.height * .44);
    final frame = Rect.fromCenter(
      center: center,
      width: frameSize,
      height: frameSize,
    );
    final roundedFrame = RRect.fromRectAndRadius(
      frame,
      const Radius.circular(26),
    );

    final shadePath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(roundedFrame);
    canvas.drawPath(shadePath, Paint()..color = const Color(0x99000000));

    final glowPaint = Paint()
      ..color = color.withValues(alpha: .22 * glowOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(roundedFrame, glowPaint);

    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = captured ? 5 : 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 42.0;
    const inset = 2.0;
    final left = frame.left + inset;
    final right = frame.right - inset;
    final top = frame.top + inset;
    final bottom = frame.bottom - inset;

    final corners = <Path>[
      Path()
        ..moveTo(left, top + cornerLength)
        ..lineTo(left, top + 16)
        ..quadraticBezierTo(left, top, left + 16, top)
        ..lineTo(left + cornerLength, top),
      Path()
        ..moveTo(right - cornerLength, top)
        ..lineTo(right - 16, top)
        ..quadraticBezierTo(right, top, right, top + 16)
        ..lineTo(right, top + cornerLength),
      Path()
        ..moveTo(right, bottom - cornerLength)
        ..lineTo(right, bottom - 16)
        ..quadraticBezierTo(right, bottom, right - 16, bottom)
        ..lineTo(right - cornerLength, bottom),
      Path()
        ..moveTo(left + cornerLength, bottom)
        ..lineTo(left + 16, bottom)
        ..quadraticBezierTo(left, bottom, left, bottom - 16)
        ..lineTo(left, bottom - cornerLength),
    ];

    for (final path in corners) {
      canvas.drawPath(path, cornerPaint);
    }

    if (captured) {
      final badgeCenter = frame.center;
      canvas.drawCircle(
        badgeCenter,
        34,
        Paint()..color = const Color(0xCC07100D),
      );
      canvas.drawCircle(
        badgeCenter,
        34,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final check = Path()
        ..moveTo(badgeCenter.dx - 14, badgeCenter.dy)
        ..lineTo(badgeCenter.dx - 4, badgeCenter.dy + 10)
        ..lineTo(badgeCenter.dx + 16, badgeCenter.dy - 12);
      canvas.drawPath(
        check,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.glowOpacity != glowOpacity ||
        oldDelegate.captured != captured;
  }
}
