import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flux/models.dart';
import 'package:flux/state.dart';

import 'fake_laptop.dart';

HistoryItem failed(String id, String text,
        {bool auto = true, Duration age = const Duration(minutes: 5)}) =>
    HistoryItem(
      id: id,
      type: ItemType.text,
      data: text,
      label: text,
      ts: DateTime.now().subtract(age).millisecondsSinceEpoch,
      status: ItemStatus.failed,
      auto: auto,
    );

void main() {
  late FakeLaptop laptop;
  late AppState state;

  setUp(() async {
    laptop = FakeLaptop();
    await laptop.start();
    state = AppState()..pairing = laptop.pairing();
  });

  tearDown(() async {
    state.dispose();
    await laptop.server.close(force: true);
  });

  test('sends queued items oldest first and marks them sent', () async {
    // history is newest first, like the app keeps it
    state.history = [
      failed('new', 'second', age: const Duration(minutes: 1)),
      failed('old', 'first', age: const Duration(minutes: 10)),
    ];
    expect(state.queuedCount, 2);

    await state.flushQueue();

    expect(laptop.received.map((m) => m['id']), ['old', 'new']);
    expect(state.history.every((i) => i.status == ItemStatus.sent), isTrue);
    expect(state.history.any((i) => i.auto), isFalse);
    expect(state.queuedCount, 0);
  });

  test('leaves manual-retry and expired items alone', () async {
    state.history = [
      failed('manual', 'needs a tap', auto: false),
      failed('stale', 'too old', age: const Duration(hours: 30)),
    ];
    expect(state.queuedCount, 0);

    await state.flushQueue();

    expect(laptop.received, isEmpty);
    expect(state.history.every((i) => i.status == ItemStatus.failed), isTrue);
  });

  test('a server error is not retried forever', () async {
    laptop.sendStatus = 500;
    state.history = [failed('x', 'boom')];

    await state.flushQueue();

    expect(state.history.single.status, ItemStatus.failed);
    expect(state.history.single.auto, isFalse);
    expect(state.queuedCount, 0);
  });

  test('a changed key is not retried forever', () async {
    state.pairing = laptop.pairing(key: 'wrong');
    state.history = [failed('x', 'hello')];

    await state.flushQueue();

    expect(state.history.single.status, ItemStatus.failed);
    expect(state.history.single.auto, isFalse);
  });

  test('history saved by an older version still loads', () {
    final old = jsonEncode([
      {'id': '1', 'type': 'text', 'data': 'hi', 'label': 'hi', 'ts': 1, 'status': 'failed'}
    ]);
    final items = HistoryItem.decodeList(old);
    expect(items.single.auto, isFalse);
    // and the flag round-trips
    items.single.auto = true;
    expect(HistoryItem.decodeList(HistoryItem.encodeList(items)).single.auto, isTrue);
  });
}
