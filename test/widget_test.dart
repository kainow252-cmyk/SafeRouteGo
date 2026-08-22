import 'package:flutter_test/flutter_test.dart';
import 'package:saferoutego/main.dart';

void main() {
  testWidgets('SafeRouteGo app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SafeRouteApp());
    expect(find.byType(SafeRouteApp), findsOneWidget);
  });
}
