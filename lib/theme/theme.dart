/*
 * This file is part of wger Workout Manager <https://github.com/wger-project>.
 * Copyright (c)  2026 wger Team
 *
 * wger Workout Manager is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:table_calendar/table_calendar.dart';

// Kinetic Fitness Design System (Stitch MCP Generated)
// Athletic, high-contrast, data-dense palette for training & nutrition.

/// Electric Emerald: Dynamic progress, completed sets, primary actions.
const Color wgerPrimaryColor = Color(0xFF0DF5A4);
const Color wgerPrimaryButtonColor = Color(0xFF0DF5A4);
const Color wgerPrimaryColorLight = Color(0xFF69FFB8);

/// Cyber Amber: Energy, rest timer alerts, warning states, caloric summaries.
const Color wgerSecondaryColor = Color(0xFFFFB020);
const Color wgerSecondaryColorLight = Color(0xFFFFDDAE);

/// Vibrant Rose: High-intensity alerts, critical indicators, fat macros.
const Color wgerTertiaryColor = Color(0xFFF43F5E);

/// Deep athletic dark surfaces
const Color wgerDarkBackground = Color(0xFF12151A); // Midnight Carbon
const Color wgerDarkSurface = Color(0xFF1B2028); // Deep Carbon
const Color wgerDarkElevated = Color(0xFF252B36); // Elevated Slate

/// Specific semantic tokens for modules (Gym Mode, Nutrition, Dashboard, Script Import)
abstract class KineticTokens {
  // Gym Mode & Timer
  static const Color timerActive = Color(0xFF0DF5A4);
  static const Color timerRest = Color(0xFFFFB020);
  static const Color activeSetPill = Color(0xFF003822);
  static const Color activeSetText = Color(0xFF69FFB8);

  // Nutrition Macros
  static const Color macroProtein = Color(0xFF0DF5A4);
  static const Color macroCarbs = Color(0xFFFFB020);
  static const Color macroFat = Color(0xFFF43F5E);
  static const Color macroCalories = Color(0xFF38BDF8);

  // Script Import & Terminal
  static const Color terminalBg = Color(0xFF0A0D12);
  static const Color terminalBorder = Color(0xFF252B36);
  static const Color terminalSuccess = Color(0xFF0DF5A4);
}

const FlexSubThemesData wgerSubThemeData = FlexSubThemesData(
  fabSchemeColor: SchemeColor.primary,
  fabUseShape: true,
  fabRadius: 16.0,
  cardRadius: 16.0,
  elevatedButtonRadius: 12.0,
  filledButtonRadius: 12.0,
  outlinedButtonRadius: 12.0,
  textButtonRadius: 12.0,
  inputDecoratorBorderType: FlexInputBorderType.outline,
  inputDecoratorRadius: 12.0,
  inputDecoratorIsFilled: true,
  useMaterial3Typography: true,
  appBarScrolledUnderElevation: 2,
  navigationBarIndicatorOpacity: 1.0,
  navigationBarHeight: 64,
  navigationBarIndicatorRadius: 12.0,
  navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
  navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
  navigationBarIndicatorSchemeColor: SchemeColor.primary,
  snackBarRadius: 12.0,
  dialogRadius: 16.0,
  timePickerElementRadius: 12.0,
);

const String wgerDisplayFont = 'RobotoCondensed';
const List<FontVariation> displayFontBoldWeight = [FontVariation('wght', 700)];
const List<FontVariation> displayFontHeavyWeight = [FontVariation('wght', 800)];

// Make a light ColorScheme from the seeds.
final ColorScheme schemeLight = SeedColorScheme.fromSeeds(
  primary: const Color(0xFF00A86B), // Slightly deeper emerald for light contrast
  primaryKey: const Color(0xFF00A86B),
  secondaryKey: const Color(0xFFD97706),
  secondary: const Color(0xFFD97706),
  tertiaryKey: wgerTertiaryColor,
  brightness: Brightness.light,
  tones: FlexTones.vivid(Brightness.light),
);

// Make a dark ColorScheme from the seeds.
final ColorScheme schemeDark = SeedColorScheme.fromSeeds(
  primary: wgerPrimaryColor,
  primaryKey: wgerPrimaryColor,
  secondaryKey: wgerSecondaryColor,
  secondary: wgerSecondaryColor,
  tertiaryKey: wgerTertiaryColor,
  brightness: Brightness.dark,
  tones: FlexTones.vivid(Brightness.dark),
);

// Make a high contrast light ColorScheme from the seeds
final ColorScheme schemeLightHc = SeedColorScheme.fromSeeds(
  primaryKey: const Color(0xFF007A4D),
  secondaryKey: const Color(0xFFB45309),
  brightness: Brightness.light,
  tones: FlexTones.ultraContrast(Brightness.light),
);

// Make an ultra contrast dark ColorScheme from the seeds.
final ColorScheme schemeDarkHc = SeedColorScheme.fromSeeds(
  primaryKey: wgerPrimaryColor,
  secondaryKey: wgerSecondaryColor,
  brightness: Brightness.dark,
  tones: FlexTones.ultraContrast(Brightness.dark),
);

const wgerTextTheme = TextTheme(
  displayLarge: TextStyle(
    fontFamily: wgerDisplayFont,
    fontVariations: displayFontHeavyWeight,
  ),
  displayMedium: TextStyle(
    fontFamily: wgerDisplayFont,
    fontVariations: displayFontHeavyWeight,
  ),
  displaySmall: TextStyle(
    fontFamily: wgerDisplayFont,
    fontVariations: displayFontHeavyWeight,
  ),
  headlineLarge: TextStyle(
    fontFamily: wgerDisplayFont,
    fontVariations: displayFontBoldWeight,
  ),
  headlineMedium: TextStyle(
    fontFamily: wgerDisplayFont,
    fontVariations: displayFontBoldWeight,
  ),
  headlineSmall: TextStyle(
    fontFamily: wgerDisplayFont,
    fontVariations: displayFontBoldWeight,
  ),
  titleLarge: TextStyle(
    fontFamily: wgerDisplayFont,
    fontVariations: displayFontBoldWeight,
  ),
  titleMedium: TextStyle(
    fontFamily: wgerDisplayFont,
    fontVariations: displayFontBoldWeight,
  ),
  titleSmall: TextStyle(
    fontFamily: wgerDisplayFont,
    fontVariations: displayFontBoldWeight,
  ),
);

final wgerLightTheme = FlexThemeData.light(
  colorScheme: schemeLight,
  useMaterial3: true,
  appBarStyle: FlexAppBarStyle.primary,
  subThemesData: wgerSubThemeData,
  textTheme: wgerTextTheme,
);

final wgerDarkTheme = FlexThemeData.dark(
  colorScheme: schemeDark,
  scaffoldBackground: wgerDarkBackground,
  surface: wgerDarkSurface,
  useMaterial3: true,
  subThemesData: wgerSubThemeData,
  textTheme: wgerTextTheme,
);

final wgerLightThemeHc = FlexThemeData.light(
  colorScheme: schemeLightHc,
  useMaterial3: true,
  appBarStyle: FlexAppBarStyle.primary,
  subThemesData: wgerSubThemeData,
  textTheme: wgerTextTheme,
);

final wgerDarkThemeHc = FlexThemeData.dark(
  colorScheme: schemeDarkHc,
  scaffoldBackground: Colors.black,
  useMaterial3: true,
  subThemesData: wgerSubThemeData,
  textTheme: wgerTextTheme,
);

/// Builds a wger theme for [brightness] with the palette generated from [seed],
/// e.g. the platform's dynamic color. Sub-themes, app bar style and typography
/// match the fixed themes, so only the hues change.
ThemeData wgerThemeFromSeed(
  Color seed,
  Brightness brightness, {
  bool highContrast = false,
}) {
  final isDark = brightness == Brightness.dark;
  return (isDark ? FlexThemeData.dark : FlexThemeData.light)(
    colorScheme: SeedColorScheme.fromSeeds(
      primaryKey: seed,
      brightness: brightness,
      tones: highContrast ? FlexTones.ultraContrast(brightness) : FlexTones.vivid(brightness),
    ),
    scaffoldBackground: isDark ? wgerDarkBackground : null,
    useMaterial3: true,
    appBarStyle: isDark ? null : FlexAppBarStyle.primary,
    subThemesData: wgerSubThemeData,
    textTheme: wgerTextTheme,
  );
}

CalendarStyle getWgerCalendarStyle(ThemeData theme) {
  final scheme = theme.colorScheme;
  final selectedDecoration = BoxDecoration(
    color: scheme.primary,
    shape: BoxShape.circle,
  );
  final selectedTextStyle = TextStyle(color: scheme.onPrimary, fontSize: 16);

  return CalendarStyle(
    outsideDaysVisible: false,
    todayDecoration: BoxDecoration(
      color: scheme.secondary.withValues(alpha: 0.8),
      shape: BoxShape.circle,
    ),
    markerDecoration: BoxDecoration(
      color: theme.textTheme.headlineLarge?.color,
      shape: BoxShape.circle,
    ),
    selectedDecoration: selectedDecoration,
    selectedTextStyle: selectedTextStyle,
    rangeStartDecoration: selectedDecoration,
    rangeStartTextStyle: selectedTextStyle,
    rangeEndDecoration: selectedDecoration,
    rangeEndTextStyle: selectedTextStyle,
    rangeHighlightColor: scheme.primaryContainer.withValues(alpha: 0.5),
    weekendTextStyle: TextStyle(color: scheme.secondary),
  );
}
