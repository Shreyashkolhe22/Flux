import 'package:flutter/material.dart';

import '../main.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dot_text.dart';
import 'pairing_screen.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return SafeArea(
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final p = app.pairing;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const DotText('DEVICES', dot: 4),
                const SizedBox(height: 24),
                if (p == null)
                  Expanded(
                    child: Center(
                      child: Text('NO LAPTOP PAIRED', style: label(context, size: 11)),
                    ),
                  )
                else
                  OutlineCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.laptop, color: c.text),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: TextStyle(fontFamily: kMono, fontSize: 14, color: c.text),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${p.activeIp}:${p.port}', style: label(context, size: 10)),
                                ],
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: switch (app.link) {
                                  Link.connected => c.green,
                                  Link.offline => c.red,
                                  _ => c.textSecondary,
                                },
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
                                onPressed: app.refreshConnection,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: c.border),
                                  shape: const StadiumBorder(),
                                ),
                                child: Text('FIND AGAIN', style: label(context, color: c.text, size: 10)),
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
                                child: Text('FORGET', style: label(context, color: c.red, size: 10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (p == null)
                  OutlineButton(
                    text: 'SCAN QR TO PAIR',
                    icon: Icons.qr_code_scanner,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PairingScreen()),
                    ),
                  )
                else
                  Text(
                    'Laptop address changed or key reset?\nForget it, then scan the QR code again.',
                    style: label(context, size: 10),
                  ),
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
