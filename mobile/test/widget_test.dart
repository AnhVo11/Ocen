import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App renders role select screen', (WidgetTester tester) async {
    await tester.pumpWidget(const OcenApp());
    await tester.pumpAndSettle();
    expect(find.text('OCEN'), findsWidgets);
  });
}
