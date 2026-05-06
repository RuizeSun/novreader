import 'package:flutter_test/flutter_test.dart';
import 'package:novriidaa_reader/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NovriidaaApp());
    await tester.pumpAndSettle();
    expect(find.text('小说阅读器'), findsOneWidget);
  });
}
