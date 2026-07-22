import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/login/login_models.dart';
import '../../core/services/app_services.dart';
import 'login_approval_screen.dart';

class LoginScannerScreen extends StatefulWidget {
  const LoginScannerScreen({super.key});

  @override
  State<LoginScannerScreen> createState() => _LoginScannerScreenState();
}

class _LoginScannerScreenState extends State<LoginScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _processing = false;
  String? _error;

  Future<void> _capture(BarcodeCapture capture) async {
    if (_processing || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.trim().isEmpty) return;
    await _process(value);
  }

  Future<void> _process(String payload) async {
    setState(() {
      _processing = true;
      _error = null;
    });
    final login = AppServices.of(context).login;
    await _controller.stop();
    try {
      final challenge = await login.parseChallenge(payload);
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => LoginApprovalScreen(challenge: challenge),
        ),
      );
    } on LoginApprovalException catch (error) {
      await _showError(error.message);
    } on Object catch (error) {
      await _showError('Unable to read this login code: $error');
    }
  }

  Future<void> _showError(String message) async {
    await HapticFeedback.vibrate();
    if (!mounted) return;
    setState(() {
      _processing = false;
      _error = message;
    });
    await _controller.start();
  }

  Future<void> _manualEntry() async {
    final controller = TextEditingController();
    final payload = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter login code'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            hintText: 'pr0jectzer0://login?...',
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
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (payload != null && payload.trim().isNotEmpty) await _process(payload);
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approve Dashboard Login'),
        actions: [
          IconButton(
            tooltip: 'Toggle flashlight',
            onPressed: _processing ? null : _controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _capture),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black.withValues(alpha: .58),
                  width: 72,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(22),
                padding: const EdgeInsets.all(18),
                constraints: const BoxConstraints(maxWidth: 480),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _processing
                          ? 'Validating login code…'
                          : 'Scan the QR code shown on the Pr0jectZer0 dashboard.',
                      textAlign: TextAlign.center,
                    ),
                    if (_processing) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _processing ? null : _manualEntry,
                      icon: const Icon(Icons.content_paste_outlined),
                      label: const Text('Enter code manually'),
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
