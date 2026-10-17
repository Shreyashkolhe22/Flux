import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dot_text.dart';
import 'pairing_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _text = TextEditingController();
  final _picker = ImagePicker();
  bool _seeAll = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text;
    if (t == null || t.isEmpty) return;
    setState(() => _text.text = t);
  }

  Future<void> _send() async {
    final t = _text.text;
    if (t.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    _text.clear();
    await app.sendText(t);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final f = await _picker.pickImage(source: source);
      if (f != null) await app.sendImage(f.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the picker.')),
      );
    }
  }

  void _openSettings() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );

  void _scan() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PairingScreen()),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final connected = app.pairing != null && app.link != Link.offline;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                FluxHeader(onSettings: _openSettings),
                const SizedBox(height: 16),
                Expanded(
                  child: connected ? _body(context) : _noSignal(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- not connected ------------------------------------------------------

  Widget _noSignal(BuildContext context) {
    final c = FluxColors.of(context);
    final paired = app.pairing != null;
    return Column(
      children: [
        const Spacer(),
        DottedRing(
          size: 120,
          dots: 40,
          child: Icon(Icons.wifi_off_rounded, size: 44, color: c.text),
        ),
        const SizedBox(height: 28),
        const DotText('NO SIGNAL', dot: 5),
        const SizedBox(height: 18),
        Text(
          paired
              ? "Can't find ${app.pairing!.name}.\nConnect to the same Wi-Fi or hotspot."
              : 'Connect to the same Wi-Fi\nor scan the QR code.',
          textAlign: TextAlign.center,
          style: label(context, color: c.text, size: 11),
        ),
        const Spacer(),
        if (paired) ...[
          OutlineButton(
            text: 'RETRY',
            icon: Icons.refresh,
            onTap: app.refreshConnection,
          ),
          const SizedBox(height: 12),
        ],
        OutlineButton(text: 'SCAN QR TO PAIR', icon: Icons.qr_code_scanner, onTap: _scan),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---- connected ----------------------------------------------------------

  Widget _body(BuildContext context) {
    final c = FluxColors.of(context);
    final p = app.pairing!;
    final items = _seeAll ? app.history : app.history.take(4).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        OutlineCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              DottedRing(
                size: 56,
                child: Icon(Icons.wifi, color: c.text, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: app.link == Link.connected ? c.green : c.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          app.link == Link.connected ? 'CONNECTED' : 'CHECKING...',
                          style: label(context, size: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label(context, color: c.text, size: 13).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text('${app.network} · ${p.activeIp}', style: label(context, size: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlineCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _text,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                style: TextStyle(fontFamily: kMono, fontSize: 13, color: c.text),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Type, paste, or drop a link...',
                  hintStyle: TextStyle(fontFamily: kMono, fontSize: 13, color: c.textSecondary),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _paste,
                    icon: Icon(Icons.content_paste, size: 14, color: c.text),
                    label: Text('PASTE', style: label(context, color: c.text, size: 10)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.border),
                      shape: const StadiumBorder(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: 'Send',
                    child: Material(
                      color: c.red,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _send,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.arrow_forward, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Max 2 taps to send.', style: label(context, size: 10)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            CircleAction(
              icon: Icons.image_outlined,
              text: 'IMAGE',
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            CircleAction(
              icon: Icons.photo_camera_outlined,
              text: 'CAMERA',
              onTap: () => _pickImage(ImageSource.camera),
            ),
            const CircleAction(
              icon: Icons.description_outlined,
              text: 'FILE',
              sub: '(SOON)',
            ),
          ],
        ),
        const SizedBox(height: 22),
        const DashedLine(),
        const SizedBox(height: 18),
        Row(
          children: [
            const DotText('RECENT', dot: 2.6),
            const Spacer(),
            if (app.history.length > 4)
              InkWell(
                onTap: () => setState(() => _seeAll = !_seeAll),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    _seeAll ? 'SHOW LESS' : 'SEE ALL →',
                    style: label(context, color: c.text, size: 10),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (app.history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('NOTHING SENT YET', style: label(context, size: 10))),
          )
        else
          for (final item in items) _RecentTile(item: item),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  final HistoryItem item;
  const _RecentTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    final isImage = item.type == ItemType.image;
    final leadingIcon = item.type == ItemType.link ? Icons.link : Icons.description_outlined;

    Widget leading;
    if (isImage && File(item.data).existsSync()) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(item.data),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          cacheWidth: 120,
          errorBuilder: (_, _, _) => const SizedBox(width: 48, height: 48),
        ),
      );
    } else {
      leading = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.border)),
        child: Icon(isImage ? Icons.image_outlined : leadingIcon, color: c.text, size: 20),
      );
    }

    final Widget status = switch (item.status) {
      ItemStatus.sent => DottedRing(
          size: 28,
          dots: 16,
          child: Icon(Icons.check, size: 13, color: c.text),
        ),
      ItemStatus.pending => const DottedRing(size: 28, dots: 16),
      ItemStatus.failed => Icon(Icons.error_outline, color: c.red, size: 26),
    };

    return InkWell(
      onTap: item.status == ItemStatus.sent ? null : () => app.retry(item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: kMono, fontSize: 12, color: c.text),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.status == ItemStatus.failed
                        ? 'FAILED · TAP TO RETRY'
                        : timeAgo(item.ts),
                    style: label(context, size: 9, color: item.status == ItemStatus.failed ? c.red : null),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            status,
          ],
        ),
      ),
    );
  }
}
