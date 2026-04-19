import 'package:flutter_test/flutter_test.dart';

import 'package:testapp/main.dart';

void main() {
  testWidgets('FTMO Calculator loads', (WidgetTester tester) async {
    await tester.pumpWidget(const FTMOApp());

    expect(find.text('LOT'), findsOneWidget);
    expect(find.text('CALCULATOR'), findsOneWidget);
    expect(find.text('CALCULER LE LOT'), findsOneWidget);
  });
}