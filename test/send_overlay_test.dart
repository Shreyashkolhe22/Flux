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
    expect(find.text('Sending...'), findsOneWidget);

    app.phase = Phase.sent;
    app.phaseMessage = 'Copied to laptop clipboard.';
    app.notifyListeners();
    await t.pump();

    expect(find.text('Sending...'), findsNothing);
    expect(find.text('SENT'), findsOneWidget);
    expect(find.text('Copied to laptop clipboard.'), findsOneWidget);

    await t.tap(find.byIcon(Icons.arrow_back));
    await t.pump();
    expect(app.phase, Phase.idle);
  });
}
