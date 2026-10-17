import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _handling = false;
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null) return;
    _handling = true;

    final p = Pairing.fromQr(raw);
    if (p == null) {
      setState(() => _error = 'That is not a Flux QR code.');
      await Future<void>.delayed(const Duration(seconds: 2));
      _handling = false;
      return;
    }

    setState(() {
      _error = null;
      _verifying = true;
    });
    final ok = await app.pair(p);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _verifying = false;
        _error = "Found the QR but can't reach the laptop.\nSame Wi-Fi? Is Flux running on it?";
      });
      await Future<void>.delayed(const Duration(seconds: 3));
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: PageHeader(title: 'Scan QR code', onBack: () => Navigator.pop(context)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(kCardRadius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                        placeholderBuilder: (context) => ColoredBox(
                          color: Colors.black,
                          child: Theme(
                            data: buildTheme(Brightness.dark),
                            child: const LoadingView(text: 'Starting camera...'),
                          ),
                        ),
                        errorBuilder: (context, error) => ColoredBox(
                          color: c.surface,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                error.errorCode == MobileScannerErrorCode.permissionDenied
                                    ? 'Camera permission is needed to scan the QR code.'
                                    : 'Camera unavailable.',
                                textAlign: TextAlign.center,
                                style: label(context, color: c.text, size: 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Center(
                        child: DottedRing(size: 240, dots: 60, color: Colors.white),
                      ),
                      if (_verifying)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.82),
                          child: Theme(
                            data: buildTheme(Brightness.dark),
                            child: const LoadingView(text: 'Pairing...', sub: 'Contacting your laptop'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error ?? 'Open Flux on your laptop (tray icon)\nand scan the QR code.',
                textAlign: TextAlign.center,
                style: label(context, color: _error != null ? c.red : c.text, size: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
