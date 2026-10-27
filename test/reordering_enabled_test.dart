import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reorderable_tabbar/reorderable_tabbar.dart';

Future<TestGesture> _drag(
  WidgetTester tester,
  Finder target,
  Offset end,
) async {
  final start = tester.getCenter(target);
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 600));
  for (var step = 1; step <= 12; step++) {
    await gesture.moveTo(Offset.lerp(start, end, step / 12)!);
    await tester.pump(const Duration(milliseconds: 50));
  }
  return gesture;
}

void main() {
  for (final config in [
    (platform: TargetPlatform.macOS, handles: true, delayed: false),
    (platform: TargetPlatform.android, handles: true, delayed: false),
    (platform: TargetPlatform.android, handles: false, delayed: false),
    (platform: TargetPlatform.android, handles: false, delayed: true),
  ]) {
    testWidgets(
      'reordering can be toggled without disabling selection: $config',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: config.platform),
            home: Scaffold(
              body: _Tabs(handles: config.handles, delayed: config.delayed),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final state = tester.state<_TabsState>(find.byType(_Tabs));
        expect(find.byIcon(Icons.drag_handle), findsNothing);
        final blocked = await _drag(
          tester,
          find.text('Stock'),
          const Offset(540, 70),
        );
        await blocked.up();
        await tester.pumpAndSettle();
        expect(state.tabs, ['Stock', 'Orders', 'Equipment']);
        expect(state.reorders, 0);
        await tester.tap(find.text('Orders'));
        await tester.pumpAndSettle();
        expect(
          DefaultTabController.of(
            tester.element(find.byType(ReorderableTabBar)),
          ).index,
          1,
        );

        await tester.tap(find.text('Enable reordering'));
        await tester.pumpAndSettle();
        final handles = find.byIcon(Icons.drag_handle);
        final target = config.platform == TargetPlatform.macOS && config.handles
            ? handles.first
            : find.text('Stock');
        final gesture = await _drag(tester, target, const Offset(650, 70));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(state.tabs, ['Orders', 'Equipment', 'Stock']);
        expect(state.reorders, 1);
        await tester.tap(find.text('Disable reordering'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.drag_handle), findsNothing);
        final blockedAgain = await _drag(
          tester,
          find.text('Stock'),
          const Offset(20, 70),
        );
        await blockedAgain.up();
        await tester.pumpAndSettle();
        expect(state.tabs, ['Orders', 'Equipment', 'Stock']);
        expect(state.reorders, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('disabling reordering during a drag prevents the pending drop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: _Tabs(handles: false, delayed: false)),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state<_TabsState>(find.byType(_Tabs));
    state.setReordering(true);
    await tester.pumpAndSettle();
    final gesture = await _drag(
      tester,
      find.text('Stock'),
      const Offset(650, 70),
    );
    state.setReordering(false);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.tabs, ['Stock', 'Orders', 'Equipment']);
    expect(state.reorders, 0);
    expect(tester.takeException(), isNull);
  });
}

class _Tabs extends StatefulWidget {
  const _Tabs({required this.handles, required this.delayed});
  final bool handles;
  final bool delayed;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  final tabs = ['Stock', 'Orders', 'Equipment'];
  var enabled = false;
  var reorders = 0;

  void setReordering(bool value) => setState(() => enabled = value);

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: tabs.length,
    child: Column(
      children: [
        TextButton(
          onPressed: () => setReordering(!enabled),
          child: Text(enabled ? 'Disable reordering' : 'Enable reordering'),
        ),
        SizedBox(
          width: 600,
          child: ReorderableTabBar(
            tabs: [for (final tab in tabs) Tab(key: ValueKey(tab), text: tab)],
            enableReordering: enabled,
            buildDefaultDragHandles: widget.handles,
            useDelayedDragStartListener: widget.delayed,
            indicatorFollowsDrag: true,
            onReorder: (oldIndex, newIndex) => setState(() {
              reorders++;
              tabs.insert(newIndex, tabs.removeAt(oldIndex));
            }),
          ),
        ),
      ],
    ),
  );
}
