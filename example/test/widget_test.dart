import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reorderable_tabbar_example/main.dart';

void main() {
  testWidgets('example selects and adds tabs with material_ui', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Tab 1'), findsOneWidget);
    expect(find.text('1. Page').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Tab 3'));
    await tester.pumpAndSettle();
    expect(find.text('3. Page').hitTestable(), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Tab 5'), findsOneWidget);
    await tester.tap(find.text('Tab 5'));
    await tester.pumpAndSettle();
    expect(find.text('5. Page').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
