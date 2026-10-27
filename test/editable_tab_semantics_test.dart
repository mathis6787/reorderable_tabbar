import 'dart:ui' show SemanticsRole;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reorderable_tabbar/reorderable_tabbar.dart';

void main() {
  for (final handles in [false, true]) {
    testWidgets('clipped inline editor keeps tab semantics: handles=$handles', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = TextEditingController(text: 'Other');
      try {
        var editing = true;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.macOS),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 360,
                  child: DefaultTabController(
                    length: 2,
                    child: StatefulBuilder(
                      builder: (context, setState) => ReorderableTabBar(
                        isScrollable: true,
                        buildDefaultDragHandles: handles,
                        enableReordering: !editing,
                        reserveDragHandleSpace: true,
                        tabs: [
                          const Tab(text: 'Overview'),
                          Tab(
                            child: editing
                                ? SizedBox(
                                    width: 296,
                                    child: TextField(
                                      controller: controller,
                                      autofocus: true,
                                      onSubmitted: (_) =>
                                          setState(() => editing = false),
                                    ),
                                  )
                                : Text(controller.text),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'Operations and equipment rental',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        final bar = tester.getSemantics(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.role == SemanticsRole.tabBar,
          ),
        );
        bar.visitChildren((child) {
          expect(child.getSemanticsData().role, SemanticsRole.tab);
          return true;
        });
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        controller.dispose();
        semantics.dispose();
      }
    });
  }
}
