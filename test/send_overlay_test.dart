import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/main.dart';
import 'package:flux/screens/send_overlay.dart';
import 'package:flux/state.dart';
import 'package:flux/theme.dart';

void main() {
  testWidgets('overlay leaves "Sending..." when the send finishes', (t) async {
    app.phase = Phase.sending;
    app.phaseLabel = 'hello';
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: ListenableBuilder(
        listenable: app,
        // Const child, exactly like Shell, which is what hid the bug.
        builder: (_, _) => const SendOverlay(),
      ),
    ));
    expect(find.text('SENDING...'), findsOneWidget);

    app.phase = Phase.sent;
    app.phaseMessage = 'COPIED TO LAPTOP CLIPBOARD';
    app.notifyListeners();
    await t.pump();

    expect(find.text('SENDING...'), findsNothing);
    expect(find.text('COPIED TO LAPTOP CLIPBOARD'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    await t.tap(find.text('OK'));
    await t.pump();
    expect(app.phase, Phase.idle);
  });
}
