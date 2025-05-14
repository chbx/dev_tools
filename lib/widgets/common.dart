// https://github.com/flutter/devtools

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

const double _themFontSize = 12;

double scaleByFontFactor(double original) {
  return (original * (_themFontSize / unscaledDefaultFontSize)).roundToDouble();
}

// Method to convert degrees to radians
double degToRad(num deg) => deg * (math.pi / 180.0);

// Font size constants:
double get largeFontSize => scaleByFontFactor(unscaledLargeFontSize);
const unscaledLargeFontSize = 14.0;

double get defaultFontSize => scaleByFontFactor(unscaledDefaultFontSize);
const unscaledDefaultFontSize = 12.0;

double get smallFontSize => scaleByFontFactor(unscaledSmallFontSize);
const unscaledSmallFontSize = 10.0;

double get defaultTextFieldHeight => scaleByFontFactor(26.0);

const extraWideSearchFieldWidth = 600.0;
const wideSearchFieldWidth = 400.0;
const defaultSearchFieldWidth = 200.0;

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

const defaultScrollBarOffset = 10.0;

const defaultIconSizeBeforeScaling = 14.0;
const defaultActionsIconSizeBeforeScaling = 18.0;

double get defaultIconSize => scaleByFontFactor(defaultIconSizeBeforeScaling);

double get actionsIconSize =>
    scaleByFontFactor(defaultActionsIconSizeBeforeScaling);

double get tooltipIconSize => scaleByFontFactor(12.0);

double get tableIconSize => scaleByFontFactor(12.0);

double get defaultListItemHeight => scaleByFontFactor(24.0);

double get defaultDialogWidth => scaleByFontFactor(700.0);

double get inputDecorationElementHeight => scaleByFontFactor(20.0);


const defaultDuration = Duration(milliseconds: 200);
const defaultCurve = Curves.easeInOutCubic;

final class PaddedDivider extends StatelessWidget {
  const PaddedDivider({
    super.key,
    this.padding = const EdgeInsets.only(bottom: 10.0),
  });

  const PaddedDivider.thin({super.key})
    : padding = const EdgeInsets.only(bottom: 4.0);

  const PaddedDivider.noPadding({super.key}) : padding = EdgeInsets.zero;

  PaddedDivider.vertical({super.key, double padding = densePadding})
    : padding = EdgeInsets.symmetric(vertical: padding);

  /// The padding to place around the divider.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: const Divider(thickness: 1.0));
  }
}
