import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reorderable_tabbar/reorderable_tabbar.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    bool scrollable = false,
    bool material3 = true,
    bool delayed = false,
    bool defaultHandles = false,
    bool underline = false,
    TextDirection direction = TextDirection.ltr,
    double width = 600,
    List<String> tabs = const ['Stock', 'Orders', 'Equipment'],
    ThemeData? theme,
    TabBarThemeData? tabBarTheme,
    Color? backgroundColor,
    Color? indicatorColor,
    Decoration? indicator,
    EdgeInsetsGeometry indicatorPadding = EdgeInsets.zero,
    ValueChanged<int>? onTap,
    WidgetStateProperty<Color?>? overlayColor,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme:
            theme ??
            ThemeData(
              useMaterial3: material3,
              tabBarTheme: tabBarTheme,
              platform: defaultHandles
                  ? TargetPlatform.macOS
                  : TargetPlatform.android,
            ),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            backgroundColor: backgroundColor,
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 300,
                child: RepaintBoundary(
                  key: const ValueKey('tabContent'),
                  child: _Tabs(
                    initialTabs: tabs,
                    scrollable: scrollable,
                    delayed: delayed,
                    defaultHandles: defaultHandles,
                    underline: underline,
                    indicatorColor: indicatorColor,
                    indicator: indicator,
                    indicatorPadding: indicatorPadding,
                    onTap: onTap,
                    overlayColor: overlayColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TabController controller(WidgetTester tester) =>
      DefaultTabController.of(tester.element(find.byType(ReorderableTabBar)));

  Future<Color> paintedIndicatorColor(WidgetTester tester) async {
    final content = find.byKey(const ValueKey('tabContent'));
    final boundary = tester.renderObject<RenderRepaintBoundary>(content);
    final origin = tester.getTopLeft(content);
    final x = (tester.getCenter(find.text('Stock')).dx - origin.dx).floor();
    final y =
        (tester.getBottomLeft(find.byType(ReorderableTabBar)).dy -
                origin.dy -
                1)
            .floor();
    return (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final offset = (y * image.width + x) * 4;
        return Color.fromARGB(
          pixels.getUint8(offset + 3),
          pixels.getUint8(offset),
          pixels.getUint8(offset + 1),
          pixels.getUint8(offset + 2),
        );
      } finally {
        image.dispose();
      }
    }))!;
  }

  for (final material3 in [true, false]) {
    for (final scrollable in [true, false]) {
      testWidgets('Material ${material3 ? 3 : 2}, scrollable=$scrollable: '
          'tap and swipe keep the view synchronized', (tester) async {
        final taps = <int>[];
        await mount(
          tester,
          material3: material3,
          scrollable: scrollable,
          onTap: taps.add,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Orders'));
        await tester.pumpAndSettle();
        expect(controller(tester).index, 1);
        expect(taps, [1]);
        expect(find.text('Orders page').hitTestable(), findsOneWidget);
        await tester.drag(find.byType(TabBarView), const Offset(-550, 0));
        await tester.pumpAndSettle();
        expect(controller(tester).index, 2);
        expect(find.text('Equipment page').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('fixed tabs fit a constrained parent', (tester) async {
    await mount(tester, width: 360);
    final centers = [
      'Stock',
      'Orders',
      'Equipment',
    ].map((text) => tester.getCenter(find.text(text)).dx).toList();
    expect(centers[0], closeTo(60, 1));
    expect(centers[1], closeTo(180, 1));
    expect(centers[2], closeTo(300, 1));
  });

  testWidgets('standalone themes and WidgetState overlays are applied', (
    tester,
  ) async {
    await mount(
      tester,
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.purple,
        unselectedLabelColor: Colors.orange,
        labelStyle: TextStyle(fontSize: 19),
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.green),
    );
    final context = tester.element(find.text('Stock'));
    expect(
      DefaultTextStyle.of(context).style.color!.toARGB32(),
      Colors.purple.toARGB32(),
    );
    expect(DefaultTextStyle.of(context).style.fontSize, 19);
    expect(
      tester.widget<InkWell>(find.byType(InkWell).first).overlayColor!.resolve({
        WidgetState.hovered,
      }),
      Colors.green,
    );
  });

  for (final rtl in [false, true]) {
    for (final delayed in [false, true]) {
      testWidgets('drag reorders and preserves selected content '
          '(rtl=$rtl, delayed=$delayed)', (tester) async {
        await mount(
          tester,
          width: 600,
          direction: rtl ? TextDirection.rtl : TextDirection.ltr,
          delayed: delayed,
        );
        final start = tester.getCenter(find.text('Stock'));
        final end = tester.getCenter(find.text('Equipment'));
        final gesture = await tester.startGesture(start);
        if (delayed) await tester.pump(kLongPressTimeout);
        await gesture.moveBy(Offset(rtl ? -20 : 20, 0));
        await tester.pump();
        for (var step = 1; step <= 10; step++) {
          await gesture.moveTo(
            Offset.lerp(start, end + Offset(rtl ? -250 : 250, 0), step / 10)!,
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(milliseconds: 500));
        await gesture.up();
        await tester.pumpAndSettle();
        final state = tester.state<_TabsState>(find.byType(_Tabs));
        expect(state.lastReorder, (0, 2));
        expect(state.tabs, ['Orders', 'Equipment', 'Stock']);
        expect(controller(tester).index, 2);
        expect(find.text('Stock page').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('default desktop handles reorder with a mouse', (tester) async {
    await mount(tester, defaultHandles: true);
    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(3));
    final start = tester.getCenter(handles.first);
    final end = tester.getCenter(handles.last) + const Offset(250, 0);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(Offset.lerp(start, end, step / 10)!);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.state<_TabsState>(find.byType(_Tabs)).lastReorder, (0, 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty tabs can be populated and removed', (tester) async {
    await mount(tester, tabs: []);
    expect(tester.takeException(), isNull);
    final state = tester.state<_TabsState>(find.byType(_Tabs));
    state.replaceTabs(['Stock']);
    await tester.pumpAndSettle();
    expect(find.text('Stock'), findsOneWidget);
    state.replaceTabs([]);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final underline in [false, true]) {
    testWidgets('indicator renders in label and full-tab modes '
        '(underline=$underline)', (tester) async {
      await mount(
        tester,
        underline: underline,
        tabBarTheme: const TabBarThemeData(
          indicatorSize: TabBarIndicatorSize.label,
          indicatorColor: Colors.teal,
        ),
      );
      await tester.tap(find.text('Equipment'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('custom indicator and updated padding are respected', (
    tester,
  ) async {
    final indicator = _RecordingIndicator();
    await mount(tester, indicator: indicator);
    final initialWidth = indicator.size.value!.width;
    await mount(
      tester,
      indicator: indicator,
      indicatorPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
    expect(indicator.size.value!.width, closeTo(initialWidth - 8, .01));
    expect(tester.takeException(), isNull);
  });

  for (final underline in [false, true]) {
    for (final fromTheme in [false, true]) {
      testWidgets('preserves ${fromTheme ? 'theme' : 'widget'} indicator color '
          'matching the background (underline=$underline)', (tester) async {
        const background = Color(0xff6750a4);
        const updated = Color(0xff00897b);
        Future<void> show(Color color) => mount(
          tester,
          underline: underline,
          backgroundColor: background,
          indicatorColor: fromTheme ? null : color,
          tabBarTheme: TabBarThemeData(
            indicatorColor: fromTheme ? color : Colors.orange,
          ),
        );

        await show(background);
        expect(await paintedIndicatorColor(tester), background);
        await show(updated);
        expect(await paintedIndicatorColor(tester), updated);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Material 2 uses the secondary color when it matches primary', (
    tester,
  ) async {
    const color = Color(0xff6750a4);
    await mount(
      tester,
      backgroundColor: color,
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: color,
        colorScheme: const ColorScheme.light(primary: color, secondary: color),
      ),
    );
    expect(await paintedIndicatorColor(tester), color);
    expect(tester.takeException(), isNull);
  });
}

class _Tabs extends StatefulWidget {
  const _Tabs({
    required this.initialTabs,
    required this.scrollable,
    required this.delayed,
    required this.defaultHandles,
    required this.underline,
    this.indicatorColor,
    this.indicator,
    this.indicatorPadding = EdgeInsets.zero,
    this.onTap,
    this.overlayColor,
  });

  final List<String> initialTabs;
  final bool scrollable;
  final bool delayed;
  final bool defaultHandles;
  final bool underline;
  final Color? indicatorColor;
  final Decoration? indicator;
  final EdgeInsetsGeometry indicatorPadding;
  final ValueChanged<int>? onTap;
  final WidgetStateProperty<Color?>? overlayColor;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  late List<String> tabs = List.of(widget.initialTabs);
  (int, int)? lastReorder;

  void replaceTabs(List<String> value) => setState(() => tabs = value);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          ReorderableTabBar(
            tabs: [for (final tab in tabs) Tab(key: ValueKey(tab), text: tab)],
            buildDefaultDragHandles: widget.defaultHandles,
            useDelayedDragStartListener: widget.delayed,
            isScrollable: widget.scrollable,
            defaultIndicator: widget.underline,
            indicatorColor: widget.indicatorColor,
            indicator: widget.indicator,
            indicatorPadding: widget.indicatorPadding,
            overlayColor: widget.overlayColor,
            onTap: widget.onTap,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                lastReorder = (oldIndex, newIndex);
                tabs.insert(newIndex, tabs.removeAt(oldIndex));
              });
            },
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final tab in tabs) Center(child: Text('$tab page')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingIndicator extends Decoration {
  final ValueNotifier<Size?> size = ValueNotifier(null);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _RecordingPainter(this);
}

class _RecordingPainter extends BoxPainter {
  _RecordingPainter(this.indicator);
  final _RecordingIndicator indicator;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    indicator.size.value = configuration.size;
  }
}
