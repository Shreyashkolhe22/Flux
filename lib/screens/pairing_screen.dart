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

    setState(() => _error = null);
    final ok = await app.pair(p);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _error = "Found the QR but can't reach the laptop.\nSame Wi-Fi? Firewall allows port ${p.port}?");
      await Future<void>.delayed(const Duration(seconds: 3));
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        title: Text('PAIR LAPTOP', style: label(context, color: c.text, size: 13)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => Center(
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
                Center(
                  child: DottedRing(
                    size: 240,
                    dots: 60,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'Run the Flux server on your laptop\nand scan the QR code in its window.',
              textAlign: TextAlign.center,
              style: label(context, color: _error != null ? c.red : c.text, size: 11),
            ),
          ),
        ],
      ),
    );
  }
}
