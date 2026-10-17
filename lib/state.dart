import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api.dart';
import 'models.dart';

enum Link { unknown, checking, connected, offline }

enum Phase { idle, sending, sent, failed }

const _maxImageBytes = 4 * 1024 * 1024; // server cap is 5 MB
const _maxHistory = 50;

class AppState extends ChangeNotifier {
  SharedPreferences? _prefs;

  Pairing? pairing;
  Link link = Link.unknown;

  /// True once the laptop has answered in this session. Later re-checks keep
  /// the home screen up instead of flashing the full-screen loader.
  bool everConnected = false;

  /// False until saved pairing/history are read from disk (drives the splash).
  bool loaded = false;
  String network = 'WIFI';
  ThemeMode themeMode = ThemeMode.system;
  List<HistoryItem> history = [];

  // Send overlay.
  Phase phase = Phase.idle;
  String phaseLabel = '';
  String phaseMessage = '';
  HistoryItem? _current;
  bool fromShare = false;

  bool _busy = false;
  final _uuid = const Uuid();

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    final pj = p.getString('pairing');
    if (pj != null) {
      try {
        pairing = Pairing.fromJson(jsonDecode(pj) as Map<String, dynamic>);
      } catch (_) {}
    }
    final hj = p.getString('history');
    if (hj != null) {
      try {
        history = HistoryItem.decodeList(hj);
      } catch (_) {}
    }
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == p.getString('theme'),
      orElse: () => ThemeMode.system,
    );
    loaded = true;
    notifyListeners();
    refreshConnection();
  }

  // ---- persistence ------------------------------------------------------

  Future<void> _savePairing() async {
    final p = pairing;
    if (p == null) {
      await _prefs?.remove('pairing');
    } else {
      await _prefs?.setString('pairing', jsonEncode(p.toJson()));
    }
  }

  Future<void> _saveHistory() async {
    if (history.length > _maxHistory) {
      history = history.sublist(0, _maxHistory);
    }
    await _prefs?.setString('history', HistoryItem.encodeList(history));
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _prefs?.setString('theme', m.name);
  }

  Future<void> clearHistory() async {
    history = [];
    notifyListeners();
    await _saveHistory();
  }

  // ---- pairing & connection --------------------------------------------

  Future<bool> pair(Pairing p) async {
    link = Link.checking;
    notifyListeners();
    for (final ip in p.ips) {
      final name = await FluxApi.ping(ip, p.port, timeout: const Duration(seconds: 3));
      if (name != null) {
        pairing = Pairing(
          name: name,
          ips: p.ips,
          port: p.port,
          key: p.key,
          activeIp: ip,
        );
        await _savePairing();
        link = Link.connected;
    everConnected = true;
        await _detectNetwork();
        notifyListeners();
        return true;
      }
    }
    link = pairing == null ? Link.unknown : Link.offline;
    notifyListeners();
    return false;
  }

  Future<void> unpair() async {
    pairing = null;
    link = Link.unknown;
    everConnected = false;
    await _savePairing();
    notifyListeners();
  }

  /// Checks the saved address, falling back to a subnet search.
  Future<void> refreshConnection() async {
    final p = pairing;
    if (p == null) return;
    link = Link.checking;
    notifyListeners();
    final ip = await FluxApi.discover(p);
    if (ip != null) {
      if (ip != p.activeIp) {
        pairing = p.withIp(ip);
        await _savePairing();
      }
      link = Link.connected;
    everConnected = true;
    } else {
      link = Link.offline;
    }
    await _detectNetwork();
    notifyListeners();
  }

  Future<void> _detectNetwork() async {
    final addrs = await FluxApi.localAddresses();
    final hotspot = addrs.any((a) => RegExp(r'^(ap|swlan|wlan1)', caseSensitive: false).hasMatch(a.name));
    network = hotspot ? 'HOTSPOT' : 'WIFI';
  }

  // ---- sending ----------------------------------------------------------

  static bool isLink(String s) {
    final t = s.trim();
    if (t.contains(RegExp(r'\s'))) return false;
    final u = Uri.tryParse(t);
    return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
  }

  Future<void> sendText(String text, {bool share = false}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final link = isLink(t);
    await _sendNew(HistoryItem(
      id: _uuid.v4(),
      type: link ? ItemType.link : ItemType.text,
      data: t,
      label: t.replaceAll('\n', ' '),
      ts: DateTime.now().millisecondsSinceEpoch,
    ), share: share);
  }

  Future<void> sendImage(String path, {bool share = false}) async {
    await _sendNew(HistoryItem(
      id: _uuid.v4(),
      type: ItemType.image,
      data: path,
      label: path.split(RegExp(r'[\\/]')).last,
      ts: DateTime.now().millisecondsSinceEpoch,
    ), share: share);
  }

  Future<void> retry(HistoryItem item) async {
    if (_busy) return;
    await _deliver(item, share: false);
  }

  Future<void> _sendNew(HistoryItem item, {required bool share}) async {
    if (_busy) return;
    history.insert(0, item);
    await _saveHistory();
    await _deliver(item, share: share);
  }

  Future<void> _deliver(HistoryItem item, {required bool share}) async {
    _busy = true;
    _current = item;
    fromShare = share;
    phase = Phase.sending;
    phaseLabel = item.label;
    item.status = ItemStatus.pending;
    notifyListeners();

    if (pairing == null) {
      _fail(item, 'Pair with your laptop first.');
      await _saveHistory();
      _busy = false;
      notifyListeners();
      return;
    }

    final result = await _attempt(item);
    switch (result) {
      case SendResult.ok:
        item.status = ItemStatus.sent;
        phase = Phase.sent;
        phaseMessage = item.type == ItemType.image
            ? 'Saved to Downloads/Flux on laptop.'
            : 'Copied to laptop clipboard.';
        link = Link.connected;
    everConnected = true;
      case SendResult.badKey:
        _fail(item, 'Laptop key changed. Scan the QR again.');
      case SendResult.tooLarge:
        _fail(item, 'File is too large to send.');
      case SendResult.unreachable:
        link = Link.offline;
        _fail(item, "Couldn't reach your laptop.");
      case SendResult.error:
        _fail(item, "Couldn't send. Try again.");
    }
    await _saveHistory();
    _busy = false;
    notifyListeners();
  }

  void _fail(HistoryItem item, String msg) {
    item.status = ItemStatus.failed;
    phase = Phase.failed;
    phaseMessage = msg;
  }

  Future<SendResult> _attempt(HistoryItem item) async {
    var p = pairing!;

    String data;
    String? mime;
    if (item.type == ItemType.image) {
      final bytes = await _prepareImage(item.data);
      if (bytes == null) return SendResult.error;
      if (bytes.length > _maxImageBytes) return SendResult.tooLarge;
      data = base64Encode(bytes);
      mime = 'image/jpeg';
    } else {
      data = item.data;
    }

    Future<SendResult> go() => FluxApi.send(p, id: item.id, type: item.type, data: data, mime: mime);

    var r = await go();
    if (r == SendResult.unreachable) {
      // Laptop IP may have changed: search the subnet, then try once more.
      final ip = await FluxApi.discover(p);
      if (ip != null) {
        p = pairing = p.withIp(ip);
        await _savePairing();
        r = await go();
      }
    }
    return r;
  }

  /// Compresses to JPEG, lowering quality until it fits the size cap.
  Future<List<int>?> _prepareImage(String path) async {
    try {
      if (!File(path).existsSync()) return null;
      for (final q in const [85, 70, 55, 40]) {
        final out = await FlutterImageCompress.compressWithFile(
          path,
          quality: q,
          minWidth: 2048,
          minHeight: 2048,
          format: CompressFormat.jpeg,
        );
        if (out == null) return null;
        if (out.length <= _maxImageBytes) return out;
      }
    } catch (_) {}
    return null;
  }

  void dismissPhase() {
    phase = Phase.idle;
    _current = null;
    notifyListeners();
  }

  Future<void> retryCurrent() async {
    final item = _current;
    if (item == null) return;
    _busy = false;
    await _deliver(item, share: fromShare);
  }
}
