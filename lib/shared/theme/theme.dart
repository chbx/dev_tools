import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

const unscaledDefaultFontSize = 14.0;

const defaultIconSizeBeforeScaling = 14.0;
const defaultActionsIconSizeBeforeScaling = 18.0;

// Padding / spacing constants:
const extraLargeSpacing = 32.0;
const largeSpacing = 16.0;
const defaultSpacing = 12.0;
const intermediateSpacing = 10.0;
const denseSpacing = 8.0;

const defaultTabBarPadding = 14.0;
const tabBarSpacing = 8.0;
const denseRowSpacing = 6.0;

const hoverCardBorderSize = 2.0;
const borderPadding = 2.0;
const densePadding = 4.0;
const noPadding = 0.0;

const extraWideSearchFieldWidth = 600.0;
const wideSearchFieldWidth = 400.0;
const defaultSearchFieldWidth = 200.0;

// Other UI related constants:
final defaultBorderRadius = BorderRadius.circular(_defaultBorderRadiusValue);
const defaultRadius = Radius.circular(_defaultBorderRadiusValue);
const _defaultBorderRadiusValue = 16.0;

// Duration and animation constants:

/// A short duration to use for animations.
///
/// Use this when you want less emphasis on the animation and more on the
/// animation result, or when you have multiple animations running in sequence
/// For example, in the timeline we use this when we are zooming the flame chart
/// and scrolling to an offset immediately after.
const shortDuration = Duration(milliseconds: 50);

/// A longer duration than [shortDuration] but quicker than [defaultDuration].
///
/// Use this for thinks that would show a bit of animation, but that we want to
/// effectively seem immediate to users.
const rapidDuration = Duration(milliseconds: 100);

/// The default duration to use for animations.
const defaultDuration = Duration(milliseconds: 200);

/// A long duration to use for animations.
///
/// Use this rarely, only when you want added emphasis to an animation.
const longDuration = Duration(milliseconds: 400);

/// The default curve we use for animations.
///
/// Inspector animations benefit from a symmetric animation curve which makes
/// it easier to reverse animations.
const defaultCurve = Curves.easeInOutCubic;

mixin ScaleByFontThemeBase {
  double get fontSize;

  double scaleByFontFactor(double original) {
    return (original * (fontSize / unscaledDefaultFontSize)).roundToDouble();
  }

  double get defaultIconSize => scaleByFontFactor(defaultIconSizeBeforeScaling);

  double get defaultTextFieldHeight => scaleByFontFactor(26.0);

  double get defaultTextFieldNumberWidth => scaleByFontFactor(100.0);

  double get inputDecorationElementHeight => scaleByFontFactor(20.0);

  double get defaultRowHeight => scaleByFontFactor(20.0);

}
