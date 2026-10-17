import 'package:flutter_test/flutter_test.dart';
import 'package:flux/models.dart';
import 'package:flux/state.dart';

void main() {
  test('parses a pairing QR', () {
    final p = Pairing.fromQr(
        'flux://pair?ips=192.168.43.20,10.0.0.5&port=3000&key=abc&name=LAPTOP');
    expect(p, isNotNull);
    expect(p!.ips, ['192.168.43.20', '10.0.0.5']);
    expect(p.port, 3000);
    expect(p.key, 'abc');
    expect(p.name, 'LAPTOP');
    expect(p.activeIp, '192.168.43.20');
  });

  test('rejects foreign or incomplete QR codes', () {
    expect(Pairing.fromQr('https://example.com'), isNull);
    expect(Pairing.fromQr('flux://pair?ips=1.2.3.4&port=3000'), isNull);
    expect(Pairing.fromQr('flux://pair?port=3000&key=k'), isNull);
  });

  test('classifies links vs text', () {
    expect(AppState.isLink('https://github.com/x'), isTrue);
    expect(AppState.isLink('  http://a.b  '), isTrue);
    expect(AppState.isLink('Check this https://github.com'), isFalse);
    expect(AppState.isLink('hello'), isFalse);
  });
}
