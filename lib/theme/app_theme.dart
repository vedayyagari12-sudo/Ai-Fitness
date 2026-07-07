import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Today/Dashboard design tokens ────────────────────────────────────────────
// Self-contained palette + type scale for the Today screen (Step 1 spec).
// Top-level so they don't touch the app-wide `AppColors` class below.
// Palette matched to the reference screenshots: near-black canvas with
// lime / blue / cyan / pink / gold accents. Each main tab owns an accent
// (TODAY lime · SCAN blue · BODY pink · TRAIN cyan).
const kBgDeep = Color(0xFF0A0A0A);
const kBgCard = Color(0xFF141414);
const kBgElevated = Color(0xFF1C1C1C);
const kBgHighlight = Color(0xFF262629);
const kLime = Color(0xFFC4FF33);
const kBlue = Color(0xFF1CA7F0);
const kCyan = Color(0xFF00C4D4);
const kPink = Color(0xFFFF3B79);
const kGold = Color(0xFFFFD23F);
const kPurple = Color(0xFF8B5CF6);
const kGreen = Color(0xFF34D399);
const kOrange = Color(0xFFFF8C00);
const kTextPrimary = Color(0xFFFFFFFF);
const kTextSecondary = Color(0xFF8A8A8A);
const kTextMuted = Color(0xFF62626C);
const kBorder = Color(0xFF242424);

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
TextStyle get kHeadlineMedium =>
    GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary);
TextStyle get kTitleLarge =>
    GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary);
TextStyle get kLabelSmall => GoogleFonts.inter(
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.8,
  color: kTextMuted,
);
TextStyle get kBodyMedium =>
    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: kTextPrimary);
TextStyle get kBodySmall =>
    GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: kTextMuted);
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
  static const Color ringStand = Color(0xFFFFFFFF);
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
