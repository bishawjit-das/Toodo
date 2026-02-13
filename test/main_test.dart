import 'package:flutter_test/flutter_test.dart';
import 'package:toodo/main.dart';

void main() {
  testWidgets('MainApp builds with router', (tester) async {
    await tester.pumpWidget(const MainApp());
    expect(find.text('Home'), findsOneWidget);
  });
}
