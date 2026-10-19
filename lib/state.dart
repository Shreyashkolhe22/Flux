import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api.dart';
import 'models.dart';
import 'network.dart';

enum Link { unknown, checking, connected, offline }

enum Phase { idle, sending, sent, failed }

const _maxImageBytes = 4 * 1024 * 1024; // server cap is 5 MB
const _maxHistory = 50;
const _autoRetryMaxAge = Duration(hours: 24);
const _queueTick = Duration(seconds: 20);
/// Every Nth tick also searches the whole subnet, in case the laptop got a new address.
const _deepSearchEvery = 6;

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

  /// Upload progress (0 to 1) while a file is being sent, otherwise null.
  double? progress;
  int _lastProgressTick = 0;

  /// Largest file the app will send. The laptop accepts up to 100 MB.
  static int maxFileBytes = 100 * 1024 * 1024;

  bool _busy = false;
  bool _flushing = false;
  int _ticks = 0;
  Timer? _queueTimer;
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
    _queueTimer ??= Timer.periodic(_queueTick, (_) => _tick());
    refreshConnection();
  }

  @override
  void dispose() {
    _queueTimer?.cancel();
    super.dispose();
  }

  /// Re-reads pairing and history from disk. The widget and the quick-settings tile
  /// (native code) write to the same saved data while the app is in the background.
  Future<void> reloadFromDisk() async {
    final p = _prefs;
    if (p == null || _busy || _flushing) return;
    await p.reload();
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
    notifyListeners();
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
    await WifiBinder.bind();
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
    if (link == Link.connected) unawaited(flushQueue());
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

  /// Sends any file (PDF, document, zip, ...). [name] is the original filename
  /// when the path is a cached copy with a different name.
  Future<void> sendFile(String path, {String? name, bool share = false}) async {
    await _sendNew(HistoryItem(
      id: _uuid.v4(),
      type: ItemType.file,
      data: path,
      label: name ?? path.split(RegExp(r'[\\/]')).last,
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
    progress = null;
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
    progress = null;
    switch (result) {
      case SendResult.ok:
        item.status = ItemStatus.sent;
        phase = Phase.sent;
        phaseMessage = item.type == ItemType.image || item.type == ItemType.file
            ? 'Saved to Downloads/Flux on laptop.'
            : 'Copied to laptop clipboard.';
        item.auto = false;
        link = Link.connected;
        everConnected = true;
      case SendResult.badKey:
        item.auto = false;
        _fail(item, 'Laptop key changed. Scan the QR again.');
      case SendResult.tooLarge:
        item.auto = false;
        _fail(item, item.type == ItemType.file
            ? 'File is too large (max ${maxFileBytes ~/ (1024 * 1024)} MB).'
            : 'Image is too large to send.');
      case SendResult.unreachable:
        // Keep it and send it by itself when the laptop is back.
        item.auto = true;
        link = Link.offline;
        _fail(item, "Couldn't reach your laptop.\nWill retry automatically when it's back.");
      case SendResult.error:
        item.auto = false;
        _fail(item, "Couldn't send. Try again.");
    }
    await _saveHistory();
    _busy = false;
    notifyListeners();
    if (item.status == ItemStatus.sent) unawaited(flushQueue());
  }

  void _fail(HistoryItem item, String msg) {
    item.status = ItemStatus.failed;
    phase = Phase.failed;
    phaseMessage = msg;
  }

  Future<SendResult> _attempt(HistoryItem item) async {
    var p = pairing!;

    if (item.type == ItemType.file) return _attemptFile(item);

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

  // ---- automatic retry --------------------------------------------------

  bool _isQueued(HistoryItem i) =>
      i.status == ItemStatus.failed &&
      i.auto &&
      DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(i.ts)) < _autoRetryMaxAge;

  int get queuedCount => history.where(_isQueued).length;

  /// Runs every few seconds while something is waiting for the laptop.
  Future<void> _tick() async {
    final p = pairing;
    if (p == null || !loaded || _busy || _flushing || queuedCount == 0) return;
    _ticks++;

    await WifiBinder.bind();
    String? found;
    for (final ip in {p.activeIp, ...p.ips}) {
      if (await FluxApi.ping(ip, p.port, timeout: const Duration(milliseconds: 1200)) != null) {
        found = ip;
        break;
      }
    }
    // Cheap checks first; now and then search the subnet in case the address changed.
    if (found == null && _ticks % _deepSearchEvery == 0) {
      found = await FluxApi.discover(p);
    }
    if (found == null) return;

    if (found != p.activeIp) {
      pairing = p.withIp(found);
      await _savePairing();
    }
    link = Link.connected;
        everConnected = true;
    notifyListeners();
    await flushQueue();
  }

  /// Sends every waiting item, oldest first, with no overlay. Stops at the first
  /// item that still cannot reach the laptop.
  Future<void> flushQueue() async {
    if (_flushing || _busy || pairing == null) return;
    final due = history.where(_isQueued).toList().reversed.toList();
    if (due.isEmpty) return;
    _flushing = true;
    try {
      for (final item in due) {
        if (_busy) break; // the user started their own send; let it finish first
        item.status = ItemStatus.pending;
        notifyListeners();
        final r = await _attempt(item);
        if (r == SendResult.ok) {
          item.status = ItemStatus.sent;
          item.auto = false;
          link = Link.connected;
          everConnected = true;
        } else {
          item.status = ItemStatus.failed;
          item.auto = r == SendResult.unreachable;
          if (r == SendResult.unreachable) {
            link = Link.offline;
            break;
          }
        }
      }
    } finally {
      _flushing = false;
      await _saveHistory();
      notifyListeners();
    }
  }

  Future<SendResult> _attemptFile(HistoryItem item) async {
    var p = pairing!;
    final file = File(item.data);
    if (!file.existsSync()) return SendResult.error; // cached copy was cleared
    final size = await file.length();
    if (size > maxFileBytes) return SendResult.tooLarge;

    Future<SendResult> go() => FluxApi.sendFile(
          p,
          id: item.id,
          path: item.data,
          name: item.label,
          onProgress: _onProgress,
        );

    var r = await go();
    if (r == SendResult.unreachable) {
      final ip = await FluxApi.discover(p);
      if (ip != null) {
        p = pairing = p.withIp(ip);
        await _savePairing();
        r = await go();
      }
    }
    return r;
  }

  /// Progress updates arrive per chunk; repaint at most ~10 times a second.
  void _onProgress(double value) {
    progress = value;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (value >= 1 || now - _lastProgressTick >= 100) {
      _lastProgressTick = now;
      notifyListeners();
    }
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
