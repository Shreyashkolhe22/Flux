import 'dart:convert';

enum ItemType { text, link, image }

enum ItemStatus { sent, pending, failed }

class HistoryItem {
  final String id;
  final ItemType type;

  /// Text/link content, or the local file path for images.
  final String data;
  final String label;
  final int ts;
  ItemStatus status;

  HistoryItem({
    required this.id,
    required this.type,
    required this.data,
    required this.label,
    required this.ts,
    this.status = ItemStatus.pending,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'data': data,
        'label': label,
        'ts': ts,
        'status': status.name,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        id: j['id'] as String,
        type: ItemType.values.byName(j['type'] as String),
        data: j['data'] as String,
        label: j['label'] as String,
        ts: j['ts'] as int,
        status: ItemStatus.values.byName(j['status'] as String),
      );

  static String encodeList(List<HistoryItem> l) =>
      jsonEncode(l.map((e) => e.toJson()).toList());

  static List<HistoryItem> decodeList(String s) => (jsonDecode(s) as List)
      .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

class Pairing {
  final String name;
  final List<String> ips;
  final int port;
  final String key;

  /// The address that last worked.
  final String activeIp;

  const Pairing({
    required this.name,
    required this.ips,
    required this.port,
    required this.key,
    required this.activeIp,
  });

  Pairing withIp(String ip) => Pairing(
        name: name,
        ips: ips.contains(ip) ? ips : [...ips, ip],
        port: port,
        key: key,
        activeIp: ip,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'ips': ips,
        'port': port,
        'key': key,
        'activeIp': activeIp,
      };

  factory Pairing.fromJson(Map<String, dynamic> j) => Pairing(
        name: j['name'] as String,
        ips: (j['ips'] as List).cast<String>(),
        port: j['port'] as int,
        key: j['key'] as String,
        activeIp: j['activeIp'] as String,
      );

  /// Parses `flux://pair?ips=a,b&port=3000&key=...&name=...`.
  static Pairing? fromQr(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'flux' || uri.host != 'pair') return null;
    final q = uri.queryParameters;
    final ips = (q['ips'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
    final port = int.tryParse(q['port'] ?? '');
    final key = q['key'];
    if (ips.isEmpty || port == null || key == null || key.isEmpty) return null;
    return Pairing(
      name: q['name'] ?? 'Laptop',
      ips: ips,
      port: port,
      key: key,
      activeIp: ips.first,
    );
  }
}
