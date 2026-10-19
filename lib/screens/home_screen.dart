import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
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
        final Widget page;
        if (app.pairing == null) {
          page = _welcome(context);
        } else if (app.link == Link.checking && !app.everConnected) {
          page = _checking(context);
        } else if (app.link == Link.offline) {
          page = _notConnected(context);
        } else {
          page = _home(context);
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: page,
          ),
        );
      },
    );
  }

  // ---- full-page states ---------------------------------------------------

  Widget _settingsButton(BuildContext context) => IconButton(
        tooltip: 'Settings',
        onPressed: _openSettings,
        icon: Icon(Icons.settings_outlined, color: FluxColors.of(context).text, size: 22),
      );

  Widget _welcome(BuildContext context) {
    final c = FluxColors.of(context);
    return Column(
      children: [
        PageHeader(title: 'Welcome to FLUX', trailing: _settingsButton(context)),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DottedRing(size: 84, dots: 30, child: Icon(Icons.smartphone, color: c.text, size: 32)),
            const SizedBox(width: 14),
            Text('· · · ·', style: label(context, color: c.text, size: 16)),
            const SizedBox(width: 14),
            DottedRing(size: 84, dots: 30, child: Icon(Icons.laptop, color: c.text, size: 34)),
          ],
        ),
        const SizedBox(height: 28),
        Text("Let's connect to your device", style: sans(context, size: 18)),
        const SizedBox(height: 10),
        Text('Scan the QR code to pair.', style: label(context, size: 11)),
        const Spacer(),
        PillButton(text: 'SCAN QR CODE', icon: Icons.qr_code_scanner, onTap: _scan),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _checking(BuildContext context) {
    return Column(
      children: [
        PageHeader(title: 'Connecting', trailing: _settingsButton(context)),
        Expanded(
          child: LoadingView(
            text: 'Looking for your laptop...',
            sub: app.pairing!.name,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _notConnected(BuildContext context) {
    final c = FluxColors.of(context);
    return Column(
      children: [
        PageHeader(title: 'Not Connected', trailing: _settingsButton(context)),
        const Spacer(),
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              DottedRing(size: 96, dots: 34, child: Icon(Icons.wifi, color: c.text, size: 36)),
              Positioned(
                right: 14,
                bottom: 18,
                child: Icon(Icons.close, color: c.red, size: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('No device connected', style: sans(context, size: 18)),
        const SizedBox(height: 10),
        Text(
          'Check your Wi-Fi or scan the QR code\nto pair.',
          textAlign: TextAlign.center,
          style: label(context, size: 11),
        ),
        if (app.queuedCount > 0) ...[
          const SizedBox(height: 18),
          Text(
            app.queuedCount == 1
                ? '1 ITEM WAITING • SENDS WHEN LAPTOP IS BACK'
                : '${app.queuedCount} ITEMS WAITING • SEND WHEN LAPTOP IS BACK',
            textAlign: TextAlign.center,
            style: label(context, color: c.red, size: 10),
          ),
        ],
        const Spacer(),
        PillButton(text: 'SCAN QR CODE', icon: Icons.qr_code_scanner, onTap: _scan),
        const SizedBox(height: 8),
        TextButton(
          onPressed: app.refreshConnection,
          child: Text('RETRY', style: label(context, color: c.text, size: 11)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ---- connected home -----------------------------------------------------

  Widget _home(BuildContext context) {
    final c = FluxColors.of(context);
    final p = app.pairing!;
    final items = _seeAll ? app.history : app.history.take(4).toList();
    final status = app.link == Link.connected
        ? 'CONNECTED • ${p.name.toUpperCase()}'
        : 'CHECKING...';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        FluxHeader(status: status, onSettings: _openSettings),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              SoftCard(
                padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 14),
                          child: SizedBox(width: 18, height: 20, child: CustomPaint(painter: _CursorPainter(c.text))),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _text,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            style: label(context, color: c.text, size: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Type, paste, or drop a link...',
                              hintStyle: label(context, size: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _paste,
                          icon: Icon(Icons.content_paste, size: 16, color: c.text),
                          label: Text('PASTE', style: label(context, color: c.text, size: 11)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: c.isDark ? c.bg : const Color(0xFFF5F5F5),
                            side: BorderSide(color: c.border),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                        ),
                        const Spacer(),
                        Semantics(
                          button: true,
                          label: 'Send',
                          child: Material(
                            color: c.red,
                            shape: const CircleBorder(),
                            elevation: c.isDark ? 0 : 3,
                            shadowColor: c.red.withValues(alpha: 0.4),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _send,
                              child: const SizedBox(
                                width: 52,
                                height: 52,
                                child: Icon(Icons.arrow_forward, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Max 2 taps to send.', style: label(context, size: 10)),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    sub: '(soon)',
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const DashedLine(),
              const SizedBox(height: 22),
              Row(
                children: [
                  Text(
                    'RECENT',
                    style: TextStyle(
                      fontFamily: kMono,
                      fontSize: 20,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w300,
                      color: c.text,
                    ),
                  ),
                  const Spacer(),
                  if (app.history.length > 4)
                    InkWell(
                      onTap: () => setState(() => _seeAll = !_seeAll),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Text(_seeAll ? 'SHOW LESS' : 'SEE ALL', style: label(context, color: c.text, size: 11)),
                            if (!_seeAll) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.arrow_forward, size: 16, color: c.text),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (app.history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: Text('NOTHING SENT YET', style: label(context, size: 11))),
                )
              else
                for (var i = 0; i < items.length; i++)
                  _RecentTile(item: items[i], last: i == items.length - 1),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small text-cursor mark shown before the input hint.
class _CursorPainter extends CustomPainter {
  final Color color;
  _CursorPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const r = 1.1;
    // vertical stem
    for (var y = 3.0; y <= size.height - 3; y += 3.4) {
      canvas.drawCircle(Offset(size.width / 2 + 2, y), r, p);
    }
    // top bar and left tick
    for (var x = 2.0; x <= size.width - 2; x += 3.4) {
      canvas.drawCircle(Offset(x, 2), r, p);
    }
    canvas.drawCircle(Offset(size.width / 2 - 3, size.height / 2), r, p);
    canvas.drawCircle(Offset(size.width / 2 - 6, size.height / 2), r, p);
  }

  @override
  bool shouldRepaint(_CursorPainter o) => o.color != color;
}

class _RecentTile extends StatelessWidget {
  final HistoryItem item;
  final bool last;
  const _RecentTile({required this.item, required this.last});

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    final isImage = item.type == ItemType.image;

    Widget leading;
    if (isImage && File(item.data).existsSync()) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(item.data),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          cacheWidth: 120,
          errorBuilder: (_, _, _) => const IconCircle(icon: Icons.image_outlined, size: 50),
        ),
      );
    } else {
      leading = IconCircle(
        size: 50,
        icon: isImage
            ? Icons.image_outlined
            : item.type == ItemType.link
                ? Icons.link
                : Icons.description_outlined,
      );
    }

    final Widget status = switch (item.status) {
      ItemStatus.sent => DottedRing(
          size: 30,
          dots: 18,
          child: Icon(Icons.check, size: 14, color: c.text),
        ),
      ItemStatus.pending => DottedRing(
          size: 30,
          dots: 18,
          spin: true,
          redArc: 2,
        ),
      ItemStatus.failed => DottedRing(
          size: 30,
          dots: 18,
          color: c.red,
          child: Text('!', style: TextStyle(fontFamily: kSans, fontWeight: FontWeight.w700, fontSize: 14, color: c.red)),
        ),
    };

    return InkWell(
      onTap: item.status == ItemStatus.sent ? null : () => app.retry(item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.border)),
        ),
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
                    style: sans(context, size: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.status == ItemStatus.failed
                        ? (item.auto ? 'WAITING FOR LAPTOP • WILL RETRY' : 'FAILED • TAP TO RETRY')
                        : timeAgo(item.ts),
                    style: label(
                      context,
                      size: 10,
                      color: item.status == ItemStatus.failed ? c.red : null,
                    ),
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
