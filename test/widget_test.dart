import 'package:flutter_test/flutter_test.dart';

import 'package:deleted_msg_recover/app.dart';

void main() {
  testWidgets('App boots to a screen without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const RecoverApp());
    await tester.pump();
    expect(find.byType(RecoverApp), findsOneWidget);
  });
}
