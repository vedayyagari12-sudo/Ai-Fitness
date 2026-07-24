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
const kLime = Color(0xFF1ED760);
const kBlue = Color(0xFF1CA7F0);
const kCyan = Color(0xFF00C4D4);
const kPink = Color(0xFFFF3B79);
const kGold = Color(0xFFFFD23F);
const kPurple = Color(0xFF8B5CF6);
const kGreen = Color(0xFF34D399);
const kOrange = Color(0xFFFF8C00);
// Cool bluish-white used for the hero-card lift and page backdrop — the
// WHOOP-style "bluish white into black" look. Deliberately NOT an accent
// (no green tint anywhere in the chrome).
const kSteel = Color(0xFFAEC4E4);
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
  colors: _kDark
      ? const [Color(0xFF1E2736), Color(0xFF10131A), Color(0xFF0A0A0A)]
      : const [Color(0xFFDFE7F3), Color(0xFFEDF1F8), Color(0xFFF3F4F7)],
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
TextStyle get kAxisLabel => GoogleFonts.inter(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: kTextMuted,
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

/// "The Outsiders" athlete-tracker design system for FitAI.
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

  // ── Accents (identical in both themes — stay const) ────────────────────────
  static const Color accent = kBlue; // signature blue accent
  static const Color accentMuted = Color(0xFF0E7CB8);
  static const Color accentSecondary = Color(0xFFFF3B30); // red — warnings/weak
  static const Color accentTertiary = Color(
    0xFFFF8C00,
  ); // orange — streak/at-risk
  static const Color accentViolet = Color(
    0xFF8B5CF6,
  ); // violet — variety series
  static const Color accentCyan = kCyan;
  static const Color accentLime = kLime;
  static const Color accentPink = kPink;
  static const Color accentGreen = kGreen;
  static const Color accentOrange = kOrange;
  static const Color accentPurple = kPurple;
  static const Color accentYellow = kGold;
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
        focusedBorder: const UnderlineInputBorder(
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
