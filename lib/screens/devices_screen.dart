import 'package:flutter/material.dart';

import '../main.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'pairing_screen.dart';

class DevicesScreen extends StatelessWidget {
  /// True when opened from Settings (shows a back arrow).
  final bool showBack;
  const DevicesScreen({super.key, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return SafeArea(
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final p = app.pairing;
          final checking = app.link == Link.checking;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Devices',
                  onBack: showBack ? () => Navigator.pop(context) : null,
                ),
                const SizedBox(height: 12),
                if (p == null) ...[
                  const Spacer(),
                  Center(
                    child: Column(
                      children: [
                        DottedRing(size: 84, dots: 30, child: Icon(Icons.laptop, color: c.text, size: 32)),
                        const SizedBox(height: 22),
                        Text('No laptop paired', style: sans(context, size: 18)),
                        const SizedBox(height: 10),
                        Text('Scan the QR code to pair.', style: label(context, size: 11)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  PillButton(
                    text: 'SCAN QR CODE',
                    icon: Icons.qr_code_scanner,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PairingScreen()),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const IconCircle(icon: Icons.laptop, size: 52),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: sans(context, size: 15)),
                                  const SizedBox(height: 4),
                                  Text('${p.activeIp}:${p.port}', style: label(context, size: 11)),
                                ],
                              ),
                            ),
                            if (checking)
                              const DottedRing(size: 26, dots: 14, spin: true, redArc: 2)
                            else
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: app.link == Link.connected ? c.green : c.red,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const DashedLine(),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: checking ? null : app.refreshConnection,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: c.border),
                                  shape: const StadiumBorder(),
                                ),
                                child: Text(
                                  checking ? 'SEARCHING...' : 'FIND AGAIN',
                                  style: label(context, color: c.text, size: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _confirmForget(context),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: c.red),
                                  shape: const StadiumBorder(),
                                ),
                                child: Text('FORGET', style: label(context, color: c.red, size: 11)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Laptop address changed or key reset?\nForget it, then scan the QR code again.',
                    style: label(context, size: 11),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmForget(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forget this laptop?'),
        content: const Text('You will need to scan its QR code again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Forget')),
        ],
      ),
    );
    if (ok == true) await app.unpair();
  }
}
