import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flux/models.dart';
import 'package:flux/state.dart';

import 'fake_laptop.dart';

void main() {
  late FakeLaptop laptop;
  late AppState state;
  late Directory tmp;

  setUp(() async {
    laptop = FakeLaptop();
    await laptop.start();
    state = AppState()..pairing = laptop.pairing();
    tmp = await Directory.systemTemp.createTemp('flux-file-test-');
  });

  tearDown(() async {
    AppState.maxFileBytes = 100 * 1024 * 1024;
    state.dispose();
    await laptop.server.close(force: true);
    await tmp.delete(recursive: true);
  });

  Future<File> makeFile(String name, int size) async {
    final rnd = Random(42);
    final f = File('${tmp.path}/$name');
    await f.writeAsBytes(List<int>.generate(size, (_) => rnd.nextInt(256)));
    return f;
  }

  test('uploads the exact bytes under the original name, with progress', () async {
    final f = await makeFile('cache-copy-123.tmp', 300 * 1024);
    final seen = <double>[];
    state.addListener(() {
      if (state.progress != null) seen.add(state.progress!);
    });

    await state.sendFile(f.path, name: 'रिपोर्ट é.pdf');

    expect(state.phase, Phase.sent);
    expect(state.phaseMessage, contains('Downloads/Flux'));
    expect(state.history.single.status, ItemStatus.sent);
    expect(laptop.preflights, 1);
    expect(laptop.files.keys, ['रिपोर्ट é.pdf']);
    expect(laptop.files['रिपोर्ट é.pdf'], await f.readAsBytes());
    expect(seen, isNotEmpty);
    expect(seen.last, 1.0);
    expect(state.progress, isNull);
  });

  test('a wrong key fails at the preflight, before any upload', () async {
    state.pairing = laptop.pairing(key: 'wrong');
    final f = await makeFile('a.bin', 200 * 1024);

    await state.sendFile(f.path, name: 'a.bin');

    expect(state.phase, Phase.failed);
    expect(state.phaseMessage, contains('key'));
    expect(laptop.files, isEmpty);
    expect(state.history.single.auto, isFalse); // a bad key is not retried forever
  });

  test('a missing file fails and is not retried', () async {
    await state.sendFile('${tmp.path}/gone.bin', name: 'gone.bin');

    expect(state.phase, Phase.failed);
    expect(state.history.single.auto, isFalse);
    expect(laptop.files, isEmpty);
  });

  test('a file over the size cap is refused before uploading', () async {
    AppState.maxFileBytes = 100;
    final f = await makeFile('big.bin', 200);

    await state.sendFile(f.path, name: 'big.bin');

    expect(state.phase, Phase.failed);
    expect(state.phaseMessage, contains('too large'));
    expect(laptop.files, isEmpty);
    expect(laptop.preflights, 0);
    expect(state.history.single.auto, isFalse);
  });

  test('a laptop that refuses the file (413) is not retried forever', () async {
    laptop.sendStatus = 413;
    final f = await makeFile('x.bin', 1024);

    await state.sendFile(f.path, name: 'x.bin');

    expect(state.phase, Phase.failed);
    expect(state.history.single.auto, isFalse);
  });

  test('a queued file is delivered by the auto-retry', () async {
    final f = await makeFile('later.zip', 50 * 1024);
    state.history = [
      HistoryItem(
        id: 'q1',
        type: ItemType.file,
        data: f.path,
        label: 'later.zip',
        ts: DateTime.now().millisecondsSinceEpoch,
        status: ItemStatus.failed,
        auto: true,
      ),
    ];

    await state.flushQueue();

    expect(state.history.single.status, ItemStatus.sent);
    expect(laptop.files['later.zip'], await f.readAsBytes());
  });
}
