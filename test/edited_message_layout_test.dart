import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deleted_msg_recover/core/models/media_type.dart';
import 'package:deleted_msg_recover/core/models/message.dart';
import 'package:deleted_msg_recover/l10n/generated/app_localizations.dart';
import 'package:deleted_msg_recover/widgets/message_bubble.dart';

void main() {
  final original =
      'This is the original message before it was edited. ' * 6;
  final edited = 'This is the edited version of that same long message. ' * 6;

  Message editedMessage() => Message(
    id: 1,
    sender: 'Alice',
    text: edited,
    mediaPath: null,
    mediaType: MediaType.none,
    mediaMime: null,
    timestamp: DateTime(2026, 9, 21, 12, 0).millisecondsSinceEpoch,
    removedAt: null,
    editedAt: DateTime(2026, 9, 21, 12, 5).millisecondsSinceEpoch,
    editHistory: [
      MessageEdit(
        text: original,
        changedAt: DateTime(2026, 9, 21, 12, 5).millisecondsSinceEpoch,
      ),
    ],
  );

  testWidgets('long edited message renders on multiple lines, none truncated', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MessageBubble(message: editedMessage())),
      ),
    );

    final paragraphs = tester
        .renderObjectList<RenderParagraph>(find.byType(RichText))
        .toList();

    RenderParagraph paragraphContaining(String needle) => paragraphs.firstWhere(
      (p) => p.text.toPlainText().contains(needle),
      orElse: () => fail('no rendered text contains "$needle"'),
    );

    for (final needle in ['original message before', 'edited version of']) {
      final p = paragraphContaining(needle);
      final lines = p.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: p.text.toPlainText().length),
      );
      final distinctLineTops = lines.map((b) => b.top.round()).toSet();
      // ignore: avoid_print
      print(
        '"$needle": ${distinctLineTops.length} line(s), '
        'didExceedMaxLines=${p.didExceedMaxLines}, height=${p.size.height}',
      );
      expect(p.didExceedMaxLines, isFalse, reason: '"$needle" was truncated');
      expect(
        distinctLineTops.length,
        greaterThan(1),
        reason: '"$needle" collapsed onto a single line',
      );
    }
  });
}
