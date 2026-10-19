import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'network.dart';

enum SendResult { ok, badKey, tooLarge, unreachable, error }

class FluxApi {
  static const _sendTimeout = Duration(seconds: 8);

  /// Returns the laptop name if a Flux server answers at [ip], else null.
  /// `/ping` is unauthenticated, so the key is never sent while searching.
  static Future<String?> ping(
    String ip,
    int port, {
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    try {
      final res = await http
          .get(Uri.parse('http://$ip:$port/ping'))
          .timeout(timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is Map && body['app'] == 'flux') return body['name'] as String?;
    } catch (_) {}
    return null;
  }

  static Future<SendResult> send(
    Pairing p, {
    required String id,
    required ItemType type,
    required String data,
    String? mime,
  }) async {
    await WifiBinder.bind();
    try {
      final res = await http
          .post(
            Uri.parse('http://${p.activeIp}:${p.port}/send'),
            headers: {'Content-Type': 'application/json', 'X-Key': p.key},
            body: jsonEncode({
              'id': id,
              'type': type.name,
              'data': data,
              'mime': ?mime,
            }),
          )
          .timeout(_sendTimeout);
      switch (res.statusCode) {
        case 200:
          return SendResult.ok;
        case 401:
          return SendResult.badKey;
        case 413:
          return SendResult.tooLarge;
        default:
          return SendResult.error;
      }
    } on SocketException {
      return SendResult.unreachable;
    } on TimeoutException {
      return SendResult.unreachable;
    } on http.ClientException {
      return SendResult.unreachable;
    } catch (_) {
      return SendResult.error;
    }
  }

  /// The phone's own private IPv4 addresses (skips mobile-data interfaces).
  static Future<List<({String name, String ip})>> localAddresses() async {
    final out = <({String name, String ip})>[];
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final i in ifaces) {
        if (RegExp(r'^(rmnet|ccmni|tun|dummy)', caseSensitive: false)
            .hasMatch(i.name)) {
          continue;
        }
        for (final a in i.addresses) {
          if (RegExp(r'^(192\.168\.|10\.|172\.(1[6-9]|2\d|3[01])\.)')
              .hasMatch(a.address)) {
            out.add((name: i.name, ip: a.address));
          }
        }
      }
    } catch (_) {}
    return out;
  }

  /// Finds the paired laptop. Order: last good IP, other IPs from the QR,
  /// then a /24 sweep of every local subnet. Returns the working IP or null.
  static Future<String?> discover(Pairing p) async {
    await WifiBinder.bind();
    final known = <String>{p.activeIp, ...p.ips};
    for (final ip in known) {
      if (await ping(ip, p.port) != null) return ip;
    }

    final mine = await localAddresses();
    final tried = <String>{...known};
    for (final addr in mine) {
      final prefix = addr.ip.substring(0, addr.ip.lastIndexOf('.') + 1);
      final candidates = [
        for (var i = 1; i <= 254; i++) '$prefix$i',
      ]..removeWhere((ip) => ip == addr.ip || tried.contains(ip));
      tried.addAll(candidates);

      const batch = 40;
      for (var i = 0; i < candidates.length; i += batch) {
        final chunk = candidates.skip(i).take(batch);
        final results = await Future.wait(
          chunk.map((ip) async {
            final name = await ping(
              ip,
              p.port,
              timeout: const Duration(milliseconds: 400),
            );
            return name == null ? null : ip;
          }),
        );
        final hit = results.whereType<String>().firstOrNull;
        if (hit != null) return hit;
      }
    }
    return null;
  }
}
