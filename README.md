# reorderable_tabbar

Reorderable tabs for Flutter, built with the standalone
[`material_ui`](https://pub.dev/packages/material_ui) library.

## Requirements

- Flutter 3.47.0 or newer and Dart 3.13.0 or newer.
- `material_ui` 1.7.0 or newer (including 1.8.0).
- Development SDK: Flutter 3.47.8, pinned in `.fvmrc`.

Version 2.0.0 migrates from `package:flutter/material.dart` to
`package:material_ui/material_ui.dart`. Use `MaterialApp`, `ThemeData`, `Tab`,
`TabController`, and `TabBarView` from `material_ui` in the consuming app too.
The tab bar uses its Material theme and localizations directly, so an app already
using `material_ui` does not need a compatibility bridge for this package.

The `automaticIndicatorColorAdjustment` option has been removed. Indicator colors
are used as supplied by the widget, `TabBarThemeData`, or the theme's color scheme,
including when they match the background. Remove the old argument from call sites
and choose an indicator color that contrasts with your background.

## Usage

Add this fork as a Git dependency using your fork's URL and a pinned commit, or
use a local checkout during development:

```yaml
dependencies:
  material_ui: ^1.7.0
  reorderable_tabbar:
    path: ../reorderable_tabbar
```

Import both packages:

```dart
import 'package:material_ui/material_ui.dart';
import 'package:reorderable_tabbar/reorderable_tabbar.dart';
```

Place the bar under a `MaterialApp` and a `Material` ancestor (for example an
`AppBar` or `Scaffold`). Share a `TabController`, or a `DefaultTabController`,
with the corresponding `TabBarView`. Their lengths must match the tab list.

```dart
DefaultTabController(
  length: tabs.length,
  child: Scaffold(
    appBar: AppBar(
      bottom: ReorderableTabBar(
        tabs: [for (final name in tabs) Tab(text: name)],
        isScrollable: true,
        buildDefaultDragHandles: false,
        useDelayedDragStartListener: true,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            tabs.insert(newIndex, tabs.removeAt(oldIndex));
          });
        },
      ),
    ),
    body: TabBarView(
      children: [for (final name in tabs) Center(child: Text(name))],
    ),
  ),
)
```

`newIndex` is the final index after removal. Do not decrement it when moving a
tab forward. Update the tabs and page order together in the callback; the bar
keeps the selected page associated with the moved content.

By default, desktop platforms show drag handles and mobile platforms use a
long press. To drag from anywhere on a tab, set `buildDefaultDragHandles: false`.
Then `useDelayedDragStartListener` chooses between a long press (`true`) and an
immediate drag (`false`, the default).

Style the bar with `TabBarThemeData` in `ThemeData.tabBarTheme`, or override the
label and indicator properties on `ReorderableTabBar`. `overlayColor` accepts a
`WidgetStateProperty<Color?>`. The rounded indicator remains the default;
`defaultIndicator: true` selects an underline, and `indicator` accepts a custom
`Decoration`.

Set `indicatorFollowsDrag: true` to keep the selected indicator attached to its
tab during reordering, including in the drag proxy and when another tab pushes
it. The indicator follows through the drop animation and returns to the normal
animated tab strip on drop or cancellation. It supports label/full-tab sizing,
padding and custom indicator decorations. The default is `false`.

## Example and validation

The [example](example/lib/main.dart) supports selecting, reordering, and adding
tabs, plus switching between fixed and scrollable tabs and indicator sizes.

```sh
fvm install
fvm flutter pub get
fvm flutter analyze --fatal-infos
fvm flutter test
cd example
fvm flutter pub get
fvm flutter test
fvm flutter run -d chrome
```

CI checks formatting, analysis, widget tests, and a web build on Flutter 3.47.0
with `material_ui` 1.7.0 and Flutter 3.47.8 with `material_ui` 1.8.0.

## Example video

<img src="https://raw.githubusercontent.com/OrtakProje-1/reorderable_tabbar/master/assets/Reorderable_TabBar.gif" height="500" alt="Reordering tabs">
