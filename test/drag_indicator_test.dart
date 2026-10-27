import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reorderable_tabbar/reorderable_tabbar.dart';

const _color = Color(0xff12ab34);
const _capture = ValueKey('capture');

Future<void> _mount(
  WidgetTester tester, {
  bool follows = false,
  bool scrollable = false,
  bool rtl = false,
  bool custom = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          RepaintBoundary(key: _capture, child: child!),
      theme: ThemeData(platform: TargetPlatform.android),
      home: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              child: _Tabs(
                follows: follows,
                scrollable: scrollable,
                custom: custom,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Measures the actual painted indicator, including the overlay drag proxy.
Future<Rect> _indicatorBounds(WidgetTester tester) async {
  tester.binding.scheduleFrame();
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  final result = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var left = image.width;
      var top = image.height;
      var right = -1;
      var bottom = -1;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final offset = (y * image.width + x) * 4;
          if (pixels.getUint8(offset) == 0x12 &&
              pixels.getUint8(offset + 1) == 0xab &&
              pixels.getUint8(offset + 2) == 0x34 &&
              pixels.getUint8(offset + 3) == 255) {
            if (x < left) left = x;
            if (y < top) top = y;
            if (x > right) right = x;
            if (y > bottom) bottom = y;
          }
        }
      }
      return right < 0
          ? null
          : Rect.fromLTRB(
              left.toDouble(),
              top.toDouble(),
              right + 1.0,
              bottom + 1.0,
            );
    } finally {
      image.dispose();
    }
  });
  expect(
    result,
    isNotNull,
    reason: 'The selected indicator must remain visible.',
  );
  return result!;
}

Future<TestGesture> _drag(WidgetTester tester, String tab, double dx) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.text(tab)),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(Offset(dx > 0 ? 20 : -20, 0));
  await tester.pump();
  for (var step = 0; step < 10; step++) {
    await gesture.moveBy(Offset(dx / 10, 0));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
  return gesture;
}

Future<void> _dropWithoutIndicatorJump(
  WidgetTester tester,
  TestGesture gesture, {
  bool rtl = false,
}) async {
  await gesture.up();
  await tester.pump();
  // Cover the handoff from the proxy to the strip, not just the settled
  // endpoints: a replayed selection animation can flash back for one frame.
  for (var frame = 0; frame < 40; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    final indicator = await _indicatorBounds(tester);
    expect(
      indicator.center.dx,
      closeTo(tester.getCenter(find.text('Stock')).dx + (rtl ? -2 : 2), 1.5),
      reason: 'Indicator detached on drop frame $frame',
    );
  }
}

void main() {
  for (final rtl in [false, true]) {
    for (final scrollable in [false, true]) {
      for (final follows in [false, true]) {
        testWidgets('selected indicator during drag: follows=$follows, '
            'scrollable=$scrollable, rtl=$rtl', (tester) async {
          await _mount(
            tester,
            follows: follows,
            scrollable: scrollable,
            rtl: rtl,
          );
          final initial = await _indicatorBounds(tester);
          final gesture = await _drag(tester, 'Stock', rtl ? -160 : 160);
          final moving = await _indicatorBounds(tester);
          if (follows) {
            expect(
              moving.center.dx,
              closeTo(
                tester.getCenter(find.text('Stock')).dx + (rtl ? -2 : 2),
                1.5,
              ),
            );
            expect(moving.width, closeTo(initial.width, 2));
            expect(
              (moving.center.dx - initial.center.dx).abs(),
              greaterThan(100),
            );
            await _dropWithoutIndicatorJump(tester, gesture, rtl: rtl);
            final reverseDistance =
                initial.center.dx -
                (rtl ? -2 : 2) -
                tester.getCenter(find.text('Stock')).dx;
            final reverse = await _drag(
              tester,
              'Stock',
              reverseDistance - (reverseDistance > 0 ? 20 : -20),
            );
            await _dropWithoutIndicatorJump(tester, reverse, rtl: rtl);
            expect(
              tester.state<_TabsState>(find.byType(_Tabs)).tabs.first,
              'Stock',
            );
          } else {
            expect(moving, initial);
            await gesture.up();
          }
          await tester.pumpAndSettle();
          final settled = await _indicatorBounds(tester);
          expect(
            settled.center.dx,
            closeTo(
              tester.getCenter(find.text('Stock')).dx + (rtl ? -2 : 2),
              1.5,
            ),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('indicator follows the selected tab pushed by another tab', (
    tester,
  ) async {
    await _mount(tester, follows: true);
    final initial = await _indicatorBounds(tester);
    final gesture = await _drag(tester, 'Orders', -250);
    final moving = await _indicatorBounds(tester);
    expect(
      moving.center.dx,
      closeTo(tester.getCenter(find.text('Stock')).dx + 2, 1.5),
    );
    expect(moving.width, closeTo(initial.width, 2));
    expect(moving.center.dx, greaterThan(initial.center.dx + 100));
    await _dropWithoutIndicatorJump(tester, gesture);
    await tester.pumpAndSettle();
    expect(tester.state<_TabsState>(find.byType(_Tabs)).tabs, [
      'Orders',
      'Stock',
      'Equipment',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancellation restores the normal indicator and supports another drag',
    (tester) async {
      await _mount(tester, follows: true);
      final initial = await _indicatorBounds(tester);
      final gesture = await _drag(tester, 'Stock', 160);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(await _indicatorBounds(tester), initial);
      final next = await _drag(tester, 'Stock', 120);
      expect(
        (await _indicatorBounds(tester)).center.dx,
        closeTo(tester.getCenter(find.text('Stock')).dx + 2, 1.5),
      );
      await next.cancel();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tapping still animates selection with drag following enabled', (
    tester,
  ) async {
    await _mount(tester, follows: true);
    final initial = await _indicatorBounds(tester);
    await tester.tap(find.text('Equipment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final moving = await _indicatorBounds(tester);
    final target = tester.getCenter(find.text('Equipment')).dx + 2;
    expect(moving.center.dx, greaterThan(initial.center.dx + 20));
    expect(moving.center.dx, lessThan(target - 20));
    await tester.pumpAndSettle();
    expect((await _indicatorBounds(tester)).center.dx, closeTo(target, 1.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom indicator decoration is carried by the drag proxy', (
    tester,
  ) async {
    await _mount(tester, follows: true, custom: true, scrollable: true);
    final initial = await _indicatorBounds(tester);
    final gesture = await _drag(tester, 'Stock', 160);
    final moving = await _indicatorBounds(tester);
    expect(moving.width, closeTo(initial.width, 2));
    expect(
      moving.center.dx,
      closeTo(tester.getCenter(find.text('Stock')).dx + 2, 1.5),
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(await _indicatorBounds(tester), initial);
  });
}

class _Tabs extends StatefulWidget {
  const _Tabs({
    required this.follows,
    required this.scrollable,
    required this.custom,
  });
  final bool follows;
  final bool scrollable;
  final bool custom;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  final tabs = ['Stock', 'Orders', 'Equipment'];

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: tabs.length,
    child: Column(
      children: [
        ReorderableTabBar(
          tabs: [for (final tab in tabs) Tab(key: ValueKey(tab), text: tab)],
          indicatorFollowsDrag: widget.follows,
          buildDefaultDragHandles: false,
          isScrollable: widget.scrollable,
          indicatorColor: _color,
          indicator: widget.custom ? const BoxDecoration(color: _color) : null,
          indicatorSize: widget.scrollable
              ? TabBarIndicatorSize.label
              : TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsetsDirectional.only(start: 6, end: 2),
          onReorder: (oldIndex, newIndex) => setState(() {
            tabs.insert(newIndex, tabs.removeAt(oldIndex));
          }),
        ),
        const Expanded(child: SizedBox()),
      ],
    ),
  );
}
