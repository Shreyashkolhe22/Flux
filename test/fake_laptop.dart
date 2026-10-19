import 'dart:convert';
import 'dart:io';

import 'package:flux/models.dart';

/// A tiny stand-in for the laptop. It follows the same rules as laptop/core.js:
/// the key is checked first, /file needs a body, filenames arrive URL-encoded.
class FakeLaptop {
  late final HttpServer server;
  final received = <Map<String, dynamic>>[];

  /// Files received on /file: decoded name -> bytes.
  final files = <String, List<int>>{};

  /// How many empty-body key checks (preflights) hit /file.
  int preflights = 0;

  /// Body bytes read on /file requests that were answered with 401.
  int bytesAfterRejection = 0;

  int sendStatus = 200;

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final authorised = req.headers.value('X-Key') == 'secret';
      if (req.uri.path == '/ping') {
        req.response.write(jsonEncode({'app': 'flux', 'name': 'TEST-LAPTOP'}));
      } else if (req.uri.path == '/send') {
        final body = jsonDecode(await utf8.decodeStream(req)) as Map<String, dynamic>;
        if (!authorised) {
          req.response.statusCode = 401;
        } else {
          req.response.statusCode = sendStatus;
          if (sendStatus == 200) received.add(body);
        }
      } else if (req.uri.path == '/file') {
        final length = req.contentLength;
        if (!authorised) {
          req.response.statusCode = 401;
        } else if (length <= 0) {
          preflights++;
          req.response.statusCode = 400;
        } else if (sendStatus != 200) {
          req.response.statusCode = sendStatus;
        } else {
          final bytes = <int>[];
          await for (final chunk in req) {
            bytes.addAll(chunk);
          }
          final name = Uri.decodeComponent(req.headers.value('X-Name') ?? '');
          files[name] = bytes;
        }
      }
      await req.response.close();
    });
  }

  Pairing pairing({String key = 'secret'}) => Pairing(
        name: 'TEST-LAPTOP',
        ips: ['127.0.0.1'],
        port: server.port,
        key: key,
        activeIp: '127.0.0.1',
      );
}
