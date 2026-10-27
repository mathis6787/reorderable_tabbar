## Unreleased

* Add opt-in `indicatorFollowsDrag` to keep the selected tab indicator attached
  during reordering, including drag proxies, drop animations and cancellation.
* Avoid replaying the selection animation when a followed indicator returns
  from the drag proxy to the tab strip after a drop.

## 2.0.0

* Require Flutter 3.47.0 / Dart 3.13.0 and pin development to Flutter 3.47.8.
* Migrate the library and example to standalone `material_ui` (1.7.0 or newer).
  Consumers must use the corresponding Material UI tab/controller/theme types.
* Update to `TabBarThemeData`, `WidgetStateProperty`, and current color APIs.
* Replace the legacy indicator dependency with an equivalent rounded decoration.
* Remove `automaticIndicatorColorAdjustment` and the automatic white indicator
  fallback. Widget, tab bar theme, and color scheme indicator colors are used as-is.
* Use the current reorder callback while preserving final-index semantics.
* Size fixed tabs to their parent constraints and release scroll/indicator resources.
* Modernize the example's web bootstrap, Android Gradle / built-in Kotlin setup,
  and iOS deployment target (15.0).
* Add widget regression coverage and Flutter CI.

## 1.0.6
* Fix [#3](https://github.com/OrtakProje-1/reorderable_tabbar/issues/3)
## 1.0.5
* Change example video url
## 1.0.4
* Added default drag handles
* Indicator positioning bug fix
* Change example video
* Moved to material3
## 1.0.2

* Added example video

## 1.0.0

* Added dartdoc comments

## 0.0.1

* Initial Release
