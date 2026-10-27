import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:reorderable_tabbar/reorderable_tabbar.dart';

const _capture = ValueKey('capture');
const _bar = ValueKey('bar');
const _primary = Color(0xff1265d7);
const _divider = Color(0xffabc123);

Future<void> _mount(
  WidgetTester tester, {
  required bool reorderable,
  bool dark = false,
  bool scrollable = true,
  bool material3 = true,
  TabBarThemeData? tabTheme,
  WidgetStateProperty<Color?>? overlay,
  Color? dividerColor,
  double? dividerHeight,
  List<String> labels = const ['Stock', 'Orders', 'Equipment'],
}) async {
  final surface = dark ? const Color(0xff111827) : Colors.white;
  final scheme = ColorScheme.fromSeed(
    seedColor: _primary,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(primary: _primary, surface: surface, outlineVariant: _divider);
  final tabs = [for (final label in labels) Tab(text: label)];
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          RepaintBoundary(key: _capture, child: child!),
      theme: ThemeData(
        useMaterial3: material3,
        colorScheme: scheme,
        splashFactory: InkRipple.splashFactory,
        platform: TargetPlatform.macOS,
        tabBarTheme:
            tabTheme ??
            const TabBarThemeData(
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: TextStyle(
                fontSize: 15,
                height: 1.4,
                letterSpacing: .1,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 15,
                height: 1.4,
                letterSpacing: .1,
              ),
            ),
      ),
      home: Scaffold(
        backgroundColor: surface,
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: DefaultTabController(
              length: tabs.length,
              child: reorderable
                  ? ReorderableTabBar(
                      key: _bar,
                      tabs: tabs,
                      isScrollable: scrollable,
                      buildDefaultDragHandles: false,
                      defaultIndicator: true,
                      indicatorWeight: 3,
                      indicatorFollowsDrag: true,
                      overlayColor: overlay,
                      dividerColor: dividerColor,
                      dividerHeight: dividerHeight,
                      onReorder: (_, _) {},
                    )
                  : TabBar(
                      key: _bar,
                      tabs: tabs,
                      isScrollable: scrollable,
                      tabAlignment: scrollable
                          ? TabAlignment.start
                          : TabAlignment.fill,
                      indicatorWeight: 3,
                      overlayColor: overlay,
                      dividerColor: dividerColor,
                      dividerHeight: dividerHeight,
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

InkWell _ink(WidgetTester tester, String label) => tester.widget<InkWell>(
  find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
);

Future<List<Color>> _pixels(WidgetTester tester, List<Offset> points) async {
  tester.binding.scheduleFrame();
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      return [
        for (final point in points)
          (() {
            final offset =
                (point.dy.floor() * image.width + point.dx.floor()) * 4;
            return Color.fromARGB(
              bytes.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
          })(),
      ];
    } finally {
      image.dispose();
    }
  }))!;
}

void _expectColorsClose(Color actual, Color expected) {
  for (final pair in [
    (actual.r, expected.r),
    (actual.g, expected.g),
    (actual.b, expected.b),
    (actual.a, expected.a),
  ]) {
    expect((pair.$1 - pair.$2).abs() * 255, lessThanOrEqualTo(1.01));
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Material 3 overlays match selected and unselected states: dark=$dark',
      (tester) async {
        final colors = <List<int?>>[];
        for (final reorderable in [false, true]) {
          await _mount(tester, reorderable: reorderable, dark: dark);
          colors.add([
            for (final label in ['Stock', 'Orders'])
              for (final states in [
                {WidgetState.pressed},
                {WidgetState.hovered},
                {WidgetState.focused},
                {WidgetState.hovered, WidgetState.pressed},
              ])
                _ink(tester, label).overlayColor?.resolve(states)?.toARGB32(),
          ]);
        }
        expect(colors.last, colors.first);
        expect(colors.first.take(3), everyElement(isNotNull));
      },
    );

    for (final interaction in ['hover', 'press', 'focus']) {
      testWidgets(
        'painted selected $interaction matches Material: dark=$dark',
        (tester) async {
          final colors = <Color>[];
          for (final reorderable in [false, true]) {
            await _mount(tester, reorderable: reorderable, dark: dark);
            final ink = find
                .ancestor(
                  of: find.text('Stock'),
                  matching: find.byType(InkWell),
                )
                .first;
            final sample = tester.getTopLeft(ink) + const Offset(5, 5);
            TestGesture? gesture;
            if (interaction == 'hover') {
              gesture = await tester.createGesture(
                kind: PointerDeviceKind.mouse,
              );
              await gesture.addPointer(location: const Offset(750, 250));
              await gesture.moveTo(sample);
            } else if (interaction == 'press') {
              gesture = await tester.startGesture(sample);
            } else {
              FocusManager.instance.highlightStrategy =
                  FocusHighlightStrategy.alwaysTraditional;
              addTearDown(
                () => FocusManager.instance.highlightStrategy =
                    FocusHighlightStrategy.automatic,
              );
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            }
            await tester.pump();
            // Give the drag/tap recognizers their press deadline, then let the
            // ink animation advance through actual frames in both components.
            for (var frame = 0; frame < 16; frame++) {
              await tester.pump(const Duration(milliseconds: 25));
            }
            colors.add((await _pixels(tester, [sample])).single);
            if (interaction == 'hover') await gesture!.removePointer();
            if (interaction == 'press') await gesture!.cancel();
            await tester.pumpAndSettle();
          }
          _expectColorsClose(colors.last, colors.first);
        },
      );
    }

    for (final scrollable in [false, true]) {
      testWidgets(
        'square underline and full-width divider match: dark=$dark, scrollable=$scrollable',
        (tester) async {
          final samples = <List<Color>>[];
          for (final reorderable in [false, true]) {
            await _mount(
              tester,
              reorderable: reorderable,
              dark: dark,
              scrollable: scrollable,
            );
            final bottom = tester.getBottomLeft(find.byKey(_bar)).dy;
            samples.add(
              await _pixels(tester, [
                Offset(0, bottom - 3),
                Offset(0, bottom - 2),
                Offset(0, bottom - 1),
                Offset(599, bottom - 1),
                Offset(599, bottom - 2),
              ]),
            );
          }
          expect(samples.last, samples.first);
          expect(samples.last.take(3), everyElement(_primary));
          expect(samples.last[3], _divider);
        },
      );
    }
  }

  testWidgets('overlay theme inheritance and widget override match Material', (
    tester,
  ) async {
    for (final override in [false, true]) {
      for (final reorderable in [false, true]) {
        await _mount(
          tester,
          reorderable: reorderable,
          tabTheme: const TabBarThemeData(
            overlayColor: WidgetStatePropertyAll(Colors.green),
          ),
          overlay: override ? const WidgetStatePropertyAll(Colors.red) : null,
        );
        expect(
          _ink(tester, 'Stock').overlayColor!.resolve({WidgetState.pressed}),
          override ? Colors.red : Colors.green,
        );
      }
    }
  });

  testWidgets(
    'divider honors theme, widget overrides, zero height and transparency',
    (tester) async {
      for (final config in [
        (height: null, color: null),
        (height: 1.0, color: Colors.cyan),
        (height: 0.0, color: null),
        (height: 2.0, color: Colors.transparent),
      ]) {
        final samples = <List<Color>>[];
        for (final reorderable in [false, true]) {
          await _mount(
            tester,
            reorderable: reorderable,
            tabTheme: const TabBarThemeData(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.purple,
              dividerHeight: 3,
            ),
            dividerColor: config.color,
            dividerHeight: config.height,
          );
          final bottom = tester.getBottomLeft(find.byKey(_bar)).dy;
          samples.add(
            await _pixels(tester, [
              for (var dy = 1; dy <= 4; dy++) Offset(599, bottom - dy),
            ]),
          );
        }
        expect(samples.last, samples.first);
      }
    },
  );

  testWidgets('single-tab dragging keeps valid accessibility roles', (
    tester,
  ) async {
    await _mount(tester, reorderable: true, labels: ['Stock']);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Stock')),
    );
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Material 2 keeps its divider hidden', (tester) async {
    await _mount(
      tester,
      reorderable: true,
      material3: false,
      tabTheme: const TabBarThemeData(
        dividerColor: Colors.purple,
        dividerHeight: 3,
      ),
    );
    final bottom = tester.getBottomLeft(find.byKey(_bar)).dy;
    expect(
      (await _pixels(tester, [Offset(599, bottom - 1)])).single,
      Colors.white,
    );
  });

  testWidgets('tabs expose Material tab roles and selection to accessibility', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      for (final reorderable in [false, true]) {
        await _mount(tester, reorderable: reorderable);
        final selected = tester
            .getSemantics(find.text('Stock'))
            .getSemanticsData();
        final unselected = tester
            .getSemantics(find.text('Orders'))
            .getSemanticsData();
        expect(selected.role, ui.SemanticsRole.tab);
        expect(unselected.role, ui.SemanticsRole.tab);
        expect(selected.flagsCollection.isSelected, ui.Tristate.isTrue);
        expect(unselected.flagsCollection.isSelected, ui.Tristate.isFalse);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics && w.properties.role == ui.SemanticsRole.tabBar,
          ),
          findsOneWidget,
        );
      }
    } finally {
      handle.dispose();
    }
  });
}
