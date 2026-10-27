import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reorderable_tabbar/reorderable_tabbar.dart';

Future<void> _mount(
  WidgetTester tester, {
  bool rtl = false,
  bool scrollable = true,
  bool dark = false,
  bool reserveSpace = false,
  bool showDisabledHandles = false,
  TargetPlatform platform = TargetPlatform.macOS,
  IndexedWidgetBuilder? handleBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        platform: platform,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      home: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              child: _Tabs(
                scrollable: scrollable,
                handleBuilder: handleBuilder,
                reserveSpace: reserveSpace,
                showDisabledHandles: showDisabledHandles,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final rtl in [false, true]) {
    for (final scrollable in [false, true]) {
      for (final dark in [false, true]) {
        testWidgets(
          'leading handle reserves label space: rtl=$rtl, scrollable=$scrollable, dark=$dark',
          (tester) async {
            await _mount(tester, rtl: rtl, scrollable: scrollable, dark: dark);
            final handles = find.byIcon(Icons.drag_indicator);
            expect(handles, findsNWidgets(3));
            expect(find.byIcon(Icons.drag_handle), findsNothing);
            final bar = tester.getRect(find.byType(ReorderableTabBar));
            expect(bar.height, 48);
            for (var index = 0; index < 3; index++) {
              final icon = tester.getRect(handles.at(index));
              final text = tester.getRect(
                find.text(['Stock', 'Orders', 'Equipment'][index]),
              );
              expect(icon.overlaps(text), isFalse);
              expect(icon.center.dy, closeTo(text.center.dy, .1));
              expect(
                rtl ? icon.left - text.right : text.left - icon.right,
                greaterThanOrEqualTo(2),
              );
              expect(icon.bottom, lessThanOrEqualTo(bar.bottom - 2));
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('desktop label selects; only handle reorders: rtl=$rtl', (
      tester,
    ) async {
      await _mount(tester, rtl: rtl);
      final semantics = tester.ensureSemantics();
      try {
        final state = tester.state<_TabsState>(find.byType(_Tabs));
        final start = tester.getCenter(find.text('Stock'));
        final labelDrag = await tester.startGesture(
          start,
          kind: PointerDeviceKind.mouse,
        );
        await labelDrag.moveBy(Offset(rtl ? -90 : 90, 0));
        await tester.pump(const Duration(milliseconds: 600));
        await labelDrag.up();
        await tester.pumpAndSettle();
        expect(state.reorders, 0);
        await tester.tap(find.text('Orders'));
        await tester.pumpAndSettle();
        expect(
          DefaultTabController.of(
            tester.element(find.byType(ReorderableTabBar)),
          ).index,
          1,
        );
        expect(state.taps, [1]);
        final handleStart = tester.getCenter(
          find.byIcon(Icons.drag_indicator).first,
        );
        final end =
            tester.getCenter(find.text('Equipment')) +
            Offset(rtl ? -120 : 120, 0);
        final drag = await tester.startGesture(
          handleStart,
          kind: PointerDeviceKind.mouse,
        );
        await drag.moveBy(Offset(rtl ? -20 : 20, 0));
        await tester.pump();
        for (var step = 1; step <= 12; step++) {
          await drag.moveTo(Offset.lerp(handleStart, end, step / 12)!);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await drag.up();
        await tester.pumpAndSettle();
        expect(state.tabs, ['Orders', 'Equipment', 'Stock']);
        expect(state.reorders, 1);
        expect(state.taps, [1]);
        expect(
          DefaultTabController.of(
            tester.element(find.byType(ReorderableTabBar)),
          ).index,
          0,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final rtl in [false, true]) {
    for (final scrollable in [false, true]) {
      testWidgets(
        'compact reserved space stays stable: rtl=$rtl, scrollable=$scrollable',
        (tester) async {
          await _mount(
            tester,
            rtl: rtl,
            scrollable: scrollable,
            reserveSpace: true,
          );
          final state = tester.state<_TabsState>(find.byType(_Tabs));
          final labels = {
            for (final name in state.tabs)
              name: tester.getRect(find.text(name)),
          };
          final widths = tester
              .widgetList<InkWell>(find.byType(InkWell))
              .map((widget) => tester.getSize(find.byWidget(widget)).width)
              .toList();
          state.setEnabled(false);
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.drag_indicator), findsNothing);
          expect(find.byType(ReorderableDragStartListener), findsNothing);
          for (final name in labels.keys) {
            expect(tester.getRect(find.text(name)), labels[name]);
          }
          expect(
            tester
                .widgetList<InkWell>(find.byType(InkWell))
                .map((widget) => tester.getSize(find.byWidget(widget)).width)
                .toList(),
            widths,
          );
          await tester.tap(find.text('Orders'));
          await tester.pumpAndSettle();
          expect(state.taps, [1]);
          state.setEnabled(true);
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));
          for (final name in labels.keys) {
            expect(tester.getRect(find.text(name)), labels[name]);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('reserved handle space does not change mobile layout', (
    tester,
  ) async {
    await _mount(tester, platform: TargetPlatform.android);
    final before = tester.getRect(find.text('Stock'));
    await _mount(tester, platform: TargetPlatform.android, reserveSpace: true);
    expect(tester.getRect(find.text('Stock')), before);
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled handles remain visible without enabling dragging', (
    tester,
  ) async {
    await _mount(tester, reserveSpace: true, showDisabledHandles: true);
    final state = tester.state<_TabsState>(find.byType(_Tabs));
    final positions = [
      for (var i = 0; i < 3; i++)
        tester.getRect(find.byIcon(Icons.drag_indicator).at(i)),
    ];
    state.setEnabled(false);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      expect(
        tester.getRect(find.byIcon(Icons.drag_indicator).at(i)),
        positions[i],
      );
    }
    final start = tester.getCenter(find.byIcon(Icons.drag_indicator).first);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(250, 0));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.reorders, 0);
    expect(state.tabs, ['Stock', 'Orders', 'Equipment']);
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    expect(state.taps, [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom handle builder replaces only the visual', (tester) async {
    final built = <int>[];
    await _mount(
      tester,
      handleBuilder: (context, index) {
        built.add(index);
        return Icon(
          Icons.open_with,
          key: ValueKey('handle-$index'),
          color: Colors.purple,
        );
      },
    );
    expect(built.toSet(), {0, 1, 2});
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byIcon(Icons.open_with), findsNWidgets(3));
    final start = tester.getCenter(find.byKey(const ValueKey('handle-0')));
    final end = tester.getCenter(find.text('Equipment')) + const Offset(120, 0);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    for (var step = 1; step <= 12; step++) {
      await gesture.moveTo(Offset.lerp(start, end, step / 12)!);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.state<_TabsState>(find.byType(_Tabs)).tabs, [
      'Orders',
      'Equipment',
      'Stock',
    ]);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    built.clear();
    await _mount(
      tester,
      platform: TargetPlatform.android,
      handleBuilder: (context, index) {
        built.add(index);
        return const Icon(Icons.open_with);
      },
    );
    expect(built, isEmpty);
    expect(find.byIcon(Icons.open_with), findsNothing);
  });
}

class _Tabs extends StatefulWidget {
  const _Tabs({
    required this.scrollable,
    this.handleBuilder,
    this.reserveSpace = false,
    this.showDisabledHandles = false,
  });
  final bool scrollable;
  final IndexedWidgetBuilder? handleBuilder;
  final bool reserveSpace;
  final bool showDisabledHandles;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  final tabs = ['Stock', 'Orders', 'Equipment'];
  final taps = <int>[];
  var reorders = 0;
  var enabled = true;

  void setEnabled(bool value) => setState(() => enabled = value);

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: tabs.length,
    child: ReorderableTabBar(
      tabs: [for (final tab in tabs) Tab(key: ValueKey(tab), text: tab)],
      isScrollable: widget.scrollable,
      indicatorFollowsDrag: true,
      dragHandleBuilder: widget.handleBuilder,
      reserveDragHandleSpace: widget.reserveSpace,
      enableReordering: enabled,
      showDisabledDragHandles: widget.showDisabledHandles,
      onTap: taps.add,
      onReorder: (oldIndex, newIndex) => setState(() {
        reorders++;
        tabs.insert(newIndex, tabs.removeAt(oldIndex));
      }),
    ),
  );
}
