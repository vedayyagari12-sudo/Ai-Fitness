import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Today/Dashboard design tokens ────────────────────────────────────────────
// Self-contained palette + type scale for the Today screen (Step 1 spec).
// Top-level so they don't touch the app-wide `AppColors` class below.
// Palette matched to the reference screenshots: near-black canvas with
// green / blue / cyan / pink / gold accents. Each main tab owns an accent
// (TODAY green · SCAN blue · BODY pink · TRAIN cyan).
// Surfaces and text delegate to AppColors so every screen (including the
// widgets built on these k-tokens) follows the light/dark toggle.
Color get kBgDeep => AppColors.background;
Color get kBgCard => AppColors.surface;
Color get kBgElevated => AppColors.surfaceElevated;
Color get kBgHighlight => AppColors.surfaceHighlight;
// "kLime" name kept (it's referenced ~25 places as the TODAY/primary accent)
// but the value is now Spotify green, not lime.
//
// ── Why these are per-theme rather than one fixed hex ────────────────────────
// The accents were picked against a light canvas and never re-stepped for the
// near-black one the app actually ships. Measured in OKLCH they sat at
// lightness 0.75-0.88 against a #141414 card; the readable band for a dark
// surface is 0.48-0.67. That gap is what made them glare and bloom on OLED —
// kGold was the worst at L 0.88 / 12.8:1. On white they had the opposite
// problem: #1ED760 is 1.8:1 there, far under the 4.5:1 text floor.
//
// Two tiers, because a 12px label and a 90px bar do different jobs:
//   · these `k*` tokens  — icons, labels, small marks, borders. Gate is WCAG
//     text contrast (>=4.5:1) on the active surface. Lightness capped at 0.72
//     in dark so they stop haloing while staying vivid.
//   · [ChartFill]        — bar/donut/ring bodies. Gate is the full six-check
//     colour-vision standard, all-pairs, per group of colours that share one
//     chart. Deeper, because large areas of saturated colour are what actually
//     vibrate against black.
// Every value below was solved with a validator, not eyeballed; the guards in
// test/palette_test.dart re-check them so they cannot drift back out of band.
Color get kLime => _kDark ? const Color(0xFF3DBD73) : const Color(0xFF00884A);
Color get kBlue => _kDark ? const Color(0xFF1CA7F0) : const Color(0xFF007CB7);
Color get kCyan => _kDark ? const Color(0xFF27B3D6) : const Color(0xFF1A7F99);
Color get kPink => _kDark ? const Color(0xFFFF3B79) : const Color(0xFFE70063);
Color get kGold => _kDark ? const Color(0xFFC39D00) : const Color(0xFF8F7200);
Color get kPurple => _kDark ? const Color(0xFF9569FF) : const Color(0xFF8A4FFF);
Color get kGreen => _kDark ? const Color(0xFF2EBB91) : const Color(0xFF008565);
Color get kOrange => _kDark ? const Color(0xFFED8200) : const Color(0xFFB36000);

/// Chart-fill steps of the same eight hues — see the note above.
///
/// Solved so that every group of colours which shares a single chart clears
/// the all-pairs colour-vision floor: readiness rings (lime/cyan/pink),
/// calorie-status bars (green/gold/pink) and the macro donut
/// (lime/blue/orange). Worst pair in dark is deltaE 10.0, in light 10.6.
class ChartFill {
  ChartFill._();
  static Color get lime =>
      _kDark ? const Color(0xFF2EAC66) : const Color(0xFF29A963);
  static Color get blue =>
      _kDark ? const Color(0xFF006DA1) : const Color(0xFF006799);
  static Color get cyan =>
      _kDark ? const Color(0xFF00A2C5) : const Color(0xFF009FC2);
  static Color get pink =>
      _kDark ? const Color(0xFFCB0057) : const Color(0xFFB2004B);
  static Color get gold =>
      _kDark ? const Color(0xFFA38200) : const Color(0xFF957700);
  static Color get purple =>
      _kDark ? const Color(0xFF812CFF) : const Color(0xFF7D0BFF);
  static Color get green =>
      _kDark ? const Color(0xFF14AB82) : const Color(0xFF0BA880);
  static Color get orange =>
      _kDark ? const Color(0xFF9C5300) : const Color(0xFF944F00);
}

// Cool bluish-white used for the hero-card lift and page backdrop — the
// WHOOP-style "bluish white into black" look. Deliberately NOT an accent
// (no green tint anywhere in the chrome).
//
// Per-theme because it behaves very differently on the two grounds. On
// near-black a blue-steel wash reads as light catching glass. On white the
// same colour is the single largest source of blue in the app: it is painted
// over EVERY card (readiness, fuel, week strip, trend) and its chroma of
// 0.051 is more than twelve times the page background's 0.004, so the whole
// light theme picked up a cold cast. The light step keeps the direction and
// drops the saturation to roughly a third.
Color get kSteel => _kDark ? const Color(0xFFAEC4E4) : const Color(0xFFBCC3CD);
Color get kTextPrimary => AppColors.textPrimary;
Color get kTextSecondary => AppColors.textSecondary;
Color get kTextMuted => AppColors.textMuted;
Color get kBorder => AppColors.border;

// ── Contrast fills ───────────────────────────────────────────────────────────
// Faint washes painted ON TOP of a surface (progress-bar tracks, legend
// swatches, chart gridlines). These must invert with the theme — a white
// wash over a white card is literally invisible.
const _kInk = Color(0xFF0B0D12); // light-mode "ink" (same as textPrimary)
bool get _kDark => AppColors.brightness == Brightness.dark;

Color get kFillSubtle => _kDark
    ? Colors.white.withValues(alpha: 0.06)
    : _kInk.withValues(alpha: 0.08);
Color get kFillMuted => _kDark
    ? Colors.white.withValues(alpha: 0.12)
    : _kInk.withValues(alpha: 0.14);
Color get kGridline => _kDark
    ? Colors.white.withValues(alpha: 0.05)
    : _kInk.withValues(alpha: 0.07);

// ── Chart surfaces ───────────────────────────────────────────────────────────
// Three problems these fix, all measured against the #141414 card:
//  · bars floated with nothing behind them, so a chart read as scattered marks
//    rather than a set of meters;
//  · the "nothing logged that day" stub used kBgHighlight (#262629) at 1.23:1
//    — invisible, so an unlogged day looked identical to a missing one;
//  · kGridline (white @5%) vanishes entirely on this card.

/// Faint slot a bar sits in, so a chart reads as a set of meters.
Color get kChartTrack => _kDark
    ? Colors.white.withValues(alpha: 0.07)
    : _kInk.withValues(alpha: 0.06);

/// A deliberate "no data here" mark. Must read as a mark, not as the track —
/// an unlogged day is information, not absence of a bar.
Color get kChartEmpty => _kDark
    ? Colors.white.withValues(alpha: 0.22)
    : _kInk.withValues(alpha: 0.20);

/// Gridlines inside a chart, one step up from [kGridline] which is tuned for
/// dividers on the page rather than on a card.
Color get kChartGrid => _kDark
    ? Colors.white.withValues(alpha: 0.09)
    : _kInk.withValues(alpha: 0.08);

/// A de-emphasised member of a series — the older weeks sitting behind the
/// latest one.
///
/// Blended toward a mid grey, NOT toward the card. Fading a colour into the
/// surface is the obvious move and the wrong one: it removes exactly the
/// lightness difference that made the bar visible. The charts used to do this
/// with `withValues(alpha: 0.45)` and the older bars measured 1.8:1 (strength,
/// purple) and 2.7:1 (volume, cyan) — present in the widget tree, invisible on
/// screen. Pulling chroma out against a neutral instead drops the emphasis
/// without dropping the contrast: the same bars now land between 3.4 and 5.5:1.
Color chartMuted(Color c) => Color.lerp(
  c,
  _kDark ? const Color(0xFF8A8A8A) : const Color(0xFF6E7480),
  0.6,
)!;

// ── Body map ─────────────────────────────────────────────────────────────────
// Unscored regions and the never-scored head/neck. The contour stroke is what
// guarantees the silhouette reads even when a fill is low-contrast.
Color get kBodyUnscored => _kDark
    ? Colors.white.withValues(alpha: 0.10)
    : _kInk.withValues(alpha: 0.13);
Color get kBodyNeutral => _kDark
    ? Colors.white.withValues(alpha: 0.14)
    : _kInk.withValues(alpha: 0.18);
Color get kBodyContour => _kDark
    ? Colors.white.withValues(alpha: 0.30)
    : _kInk.withValues(alpha: 0.30);

// ── Gradients ────────────────────────────────────────────────────────────────
/// Page backdrop: a cool bluish-slate lift at the top settling into black
/// (dark) or a pale blue-white settling into the off-white canvas (light) —
/// the WHOOP "bluish white with black" feel. This is the only ambient
/// treatment now; the old breathing corner glows were removed.
LinearGradient get kPageGradient => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  // Light steps are near-neutral now: the old top stop carried chroma 0.018
  // against a 0.004 base, so the page itself was tinted blue before a single
  // card was drawn on it. Direction kept, saturation cut to about a third.
  colors: _kDark
      ? const [Color(0xFF1E2736), Color(0xFF10131A), Color(0xFF0A0A0A)]
      : const [Color(0xFFE3E7EB), Color(0xFFEFF1F4), Color(0xFFF3F4F6)],
  stops: const [0.0, 0.45, 1.0],
);

/// Hero-card wash: a cool bluish-white sheen at the top-left fading into the
/// normal surface, like light catching a pane of frosted glass. `alphaBlend`
/// onto [kBgCard] keeps it opaque and theme-correct. Pass [kSteel] for the
/// standard neutral lift (no green — per design direction).
LinearGradient kHeroCardGradient(Color accent) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    // A brighter cool "highlight" corner (glass catching light)…
    Color.alphaBlend(
      Colors.white.withValues(alpha: _kDark ? 0.05 : 0.0),
      Color.alphaBlend(accent.withValues(alpha: 0.13), kBgCard),
    ),
    // …settling into the plain surface, with a faint deepening at the far
    // corner so the pane reads as subtly curved.
    kBgCard,
    Color.alphaBlend(
      Colors.black.withValues(alpha: _kDark ? 0.10 : 0.03),
      kBgCard,
    ),
  ],
  stops: const [0.0, 0.55, 1.0],
);

/// Bright hairline rim for glass cards — a lit top edge in dark, a crisp cool
/// edge in light. Pair with [kGlassShadow] and [kHeroCardGradient].
Color get kGlassBorder => _kDark
    ? Colors.white.withValues(alpha: 0.10)
    : Colors.white.withValues(alpha: 0.65);

/// Soft drop shadow that lets a glass card float off the page backdrop.
List<BoxShadow> get kGlassShadow => [
  BoxShadow(
    color: Colors.black.withValues(alpha: _kDark ? 0.35 : 0.06),
    blurRadius: 24,
    offset: const Offset(0, 8),
  ),
];

// ── Numeric type scale ───────────────────────────────────────────────────────
// Stat readouts, largest → smallest. Values carry their own accent color at
// call sites via `.copyWith(color: kGold)`.
TextStyle get kStatHero => GoogleFonts.inter(
  fontSize: 52,
  fontWeight: FontWeight.w800,
  height: 1.0,
  letterSpacing: -1.5,
  color: kTextPrimary,
);
TextStyle get kStatXLarge => GoogleFonts.inter(
  fontSize: 44,
  fontWeight: FontWeight.w900,
  height: 1.0,
  letterSpacing: -1,
  color: kTextPrimary,
);
TextStyle get kStatLarge => GoogleFonts.inter(
  fontSize: 38,
  fontWeight: FontWeight.w800,
  height: 1.0,
  letterSpacing: -0.8,
  color: kTextPrimary,
);
TextStyle get kStatMedium => GoogleFonts.inter(
  fontSize: 30,
  fontWeight: FontWeight.w800,
  height: 1.0,
  letterSpacing: -0.5,
  color: kTextPrimary,
);
TextStyle get kStatSmall => GoogleFonts.inter(
  fontSize: 24,
  fontWeight: FontWeight.w800,
  height: 1.05,
  color: kTextPrimary,
);
TextStyle get kStatXSmall => GoogleFonts.inter(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  height: 1.1,
  color: kTextPrimary,
);
TextStyle get kStatCaption => GoogleFonts.inter(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: kTextSecondary,
);
// kTextMuted here measured 2.6:1 on a #141414 card — below the readable
// floor, which is why axis labels looked like they were fading out.
TextStyle get kAxisLabel => GoogleFonts.inter(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: kTextSecondary,
);

TextStyle get kDisplayLarge => GoogleFonts.inter(
  fontSize: 48,
  fontWeight: FontWeight.w700,
  letterSpacing: -1.5,
  color: kTextPrimary,
);
TextStyle get kHeadlineLarge => GoogleFonts.inter(
  fontSize: 26,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.5,
  color: kTextPrimary,
);
TextStyle get kHeadlineMedium => GoogleFonts.inter(
  fontSize: 22,
  fontWeight: FontWeight.w700,
  color: kTextPrimary,
);
TextStyle get kTitleLarge => GoogleFonts.inter(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: kTextPrimary,
);
TextStyle get kLabelSmall => GoogleFonts.inter(
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.8,
  color: kTextMuted,
);
TextStyle get kBodyMedium => GoogleFonts.inter(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: kTextPrimary,
);
TextStyle get kBodySmall => GoogleFonts.inter(
  fontSize: 11,
  fontWeight: FontWeight.w400,
  color: kTextMuted,
);
// ─────────────────────────────────────────────────────────────────────────────

/// "The Outsiders" athlete-tracker design system for Physiqo AI.
/// Dark canvas, cool-blue accent, extreme weight contrast. The dark palette
/// (`AppColors`) is the default; a light palette mirrors it for light mode.
class AppColors {
  AppColors._();

  /// Active brightness — set by the app shell when the theme changes.
  /// Surface/text getters below resolve against this so the whole app
  /// (including hardcoded `AppColors.*` usages) follows light/dark mode.
  static Brightness brightness = Brightness.dark;
  static bool get _l => brightness == Brightness.light;

  // ── Surfaces (theme-aware) ─────────────────────────────────────────────────
  static Color get background =>
      _l ? const Color(0xFFF3F4F7) : const Color(0xFF0A0A0A);
  static Color get surface =>
      _l ? const Color(0xFFFFFFFF) : const Color(0xFF141414);
  static Color get surfaceElevated =>
      _l ? const Color(0xFFEAECF0) : const Color(0xFF1C1C1C);
  static Color get surfaceHighlight =>
      _l ? const Color(0xFFDDE0E6) : const Color(0xFF262629);

  // ── Text (theme-aware) ─────────────────────────────────────────────────────
  static Color get textPrimary =>
      _l ? const Color(0xFF0B0D12) : const Color(0xFFFFFFFF);
  static Color get textSecondary =>
      _l ? const Color(0xFF5A6172) : const Color(0xFF8A8A8A);
  static Color get textMuted =>
      _l ? const Color(0xFF98A0AE) : const Color(0xFF62626C);

  // ── Lines (theme-aware) ────────────────────────────────────────────────────
  static Color get divider =>
      _l ? const Color(0x0D000000) : const Color(0xFF1C1C1C);
  static Color get border =>
      _l ? const Color(0x14000000) : const Color(0xFF242424);

  // ── Accents ───────────────────────────────────────────────────────────────
  // The eight that alias a k* token follow the theme with it (see the note on
  // those tokens); the standalone hexes below stay const.
  static Color get accent => kBlue; // signature blue accent
  static const Color accentMuted = Color(0xFF0E7CB8);
  static const Color accentSecondary = Color(0xFFFF3B30); // red — warnings/weak
  static const Color accentTertiary = Color(
    0xFFFF8C00,
  ); // orange — streak/at-risk
  static const Color accentViolet = Color(
    0xFF8B5CF6,
  ); // violet — variety series
  static Color get accentCyan => kCyan;
  static Color get accentLime => kLime;
  static Color get accentPink => kPink;
  static Color get accentGreen => kGreen;
  static Color get accentOrange => kOrange;
  static Color get accentPurple => kPurple;
  static Color get accentYellow => kGold;
  static const Color success = Color(0xFF30D158);
  static const Color error = Color(0xFFFF3B30);
  static const Color danger = Color(0xFFFF3B30);
  static const Color warningSurface = Color(0xFF2A2416);
  static const Color warningText = Color(0xFFFF8C00);

  // ── Ring / chart hues (semantic data series) ───────────────────────────────
  static const Color ringMove = Color(0xFFFF3B30);
  static const Color ringExercise = Color(0xFF22D3EE);
  static const Color chartBar = Color(0xFF3B82F6);
}

/// Light-mode surface/text palette (accents are shared with [AppColors]).
class AppColorsLight {
  AppColorsLight._();
  static const Color background = Color(0xFFF3F4F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFEAECF0);
  static const Color textPrimary = Color(0xFF0B0D12);
  static const Color textSecondary = Color(0xFF5A6172);
  static const Color textMuted = Color(0xFF98A0AE);
  static const Color border = Color(0x14000000);
  static const Color divider = Color(0x0D000000);
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => _build(
    brightness: Brightness.dark,
    background: const Color(0xFF0A0A0A),
    surface: const Color(0xFF141414),
    surfaceElevated: const Color(0xFF1C1C1C),
    textPrimary: const Color(0xFFFFFFFF),
    textSecondary: const Color(0xFF8A8A8A),
    textMuted: const Color(0xFF444444),
    border: const Color(0xFF242424),
    divider: const Color(0xFF1C1C1C),
    statusIcons: Brightness.light,
  );

  static ThemeData get lightTheme => _build(
    brightness: Brightness.light,
    background: AppColorsLight.background,
    surface: AppColorsLight.surface,
    surfaceElevated: AppColorsLight.surfaceElevated,
    textPrimary: AppColorsLight.textPrimary,
    textSecondary: AppColorsLight.textSecondary,
    textMuted: AppColorsLight.textMuted,
    border: AppColorsLight.border,
    divider: AppColorsLight.divider,
    statusIcons: Brightness.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceElevated,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color border,
    required Color divider,
    required Brightness statusIcons,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accentMuted,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      error: AppColors.error,
      onError: Colors.white,
    );

    final baseTextTheme =
        (brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light())
            .textTheme;
    final textTheme = GoogleFonts.outfitTextTheme(
      baseTextTheme,
    ).apply(bodyColor: textPrimary, displayColor: textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: divider,
      splashColor: AppColors.accent.withValues(alpha: 0.10),
      highlightColor: AppColors.accent.withValues(alpha: 0.06),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusIcons,
          statusBarBrightness: statusIcons == Brightness.light
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: statusIcons,
        ),
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentLime,
          foregroundColor: Colors.black,
          disabledBackgroundColor: surfaceElevated,
          disabledForegroundColor: textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: UnderlineInputBorder(borderSide: BorderSide(color: border)),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        deleteIconColor: textSecondary,
        labelStyle: TextStyle(color: textPrimary),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: surfaceElevated,
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(surface),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      textTheme: textTheme,
    );
  }
}
