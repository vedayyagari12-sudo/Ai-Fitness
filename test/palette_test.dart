import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physiqo_ai/theme/app_theme.dart';

/// The accents were originally picked against a light canvas and never
/// re-stepped for the near-black one the app ships, which is why they glared:
/// measured in OKLCH they sat at lightness 0.75-0.88 against a #141414 card,
/// where the readable band for a dark surface is 0.48-0.67.
///
/// Colour is computable, so these are computed rather than eyeballed. The
/// maths here mirrors the reference validator exactly — same OKLab transform,
/// same Machado-Oliveira-Fernandes (2009) colour-vision matrices at severity
/// 1.0 — so a value that passes here passes there.
void main() {
  // ── colour maths ──────────────────────────────────────────────────────────

  double toLinear(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  List<double> linearRgb(Color c) => [
    toLinear((c.r * 255).round() / 255),
    toLinear((c.g * 255).round() / 255),
    toLinear((c.b * 255).round() / 255),
  ];

  /// Perceptual lightness/chroma. OKLab, per Ottosson.
  List<double> oklabOf(List<double> rgb) {
    final r = rgb[0], g = rgb[1], b = rgb[2];
    final l = math
        .pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3)
        .toDouble();
    final m = math
        .pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3)
        .toDouble();
    final s = math
        .pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3)
        .toDouble();
    return [
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    ];
  }

  double lightness(Color c) => oklabOf(linearRgb(c))[0];

  double chroma(Color c) {
    final lab = oklabOf(linearRgb(c));
    return math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]);
  }

  double relLum(Color c) {
    final l = linearRgb(c);
    return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2];
  }

  /// Flatten a translucent colour onto its background, as the screen does.
  /// Without this, two tokens differing only in alpha measure identically.
  Color over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

  /// WCAG contrast ratio.
  double contrast(Color a, Color b) {
    final x = relLum(a), y = relLum(b);
    final hi = math.max(x, y), lo = math.min(x, y);
    return (hi + 0.05) / (lo + 0.05);
  }

  // Machado, Oliveira & Fernandes (2009), severity 1.0, in linear RGB.
  const machado = {
    'protan': [
      [0.152286, 1.052583, -0.204868],
      [0.114503, 0.786281, 0.099216],
      [-0.003882, -0.048116, 1.051998],
    ],
    'deutan': [
      [0.367322, 0.860646, -0.227968],
      [0.280085, 0.672501, 0.047413],
      [-0.011820, 0.042940, 0.968881],
    ],
  };

  List<double> simulate(Color c, String kind) {
    final l = linearRgb(c), m = machado[kind]!;
    return [
      for (var i = 0; i < 3; i++)
        math.max(
          0.0,
          math.min(1.0, m[i][0] * l[0] + m[i][1] * l[1] + m[i][2] * l[2]),
        ),
    ];
  }

  /// Euclidean distance in OKLab x100. [kind] null = unsimulated vision.
  double deltaE(Color a, Color b, [String? kind]) {
    final x = oklabOf(kind == null ? linearRgb(a) : simulate(a, kind));
    final y = oklabOf(kind == null ? linearRgb(b) : simulate(b, kind));
    return 100 *
        math.sqrt(
          math.pow(x[0] - y[0], 2) +
              math.pow(x[1] - y[1], 2) +
              math.pow(x[2] - y[2], 2),
        );
  }

  // ── harness ───────────────────────────────────────────────────────────────

  // AppColors.brightness is global mutable static state. Without restoring it
  // this file would silently repaint every widget test that runs after it.
  late Brightness saved;
  setUp(() => saved = AppColors.brightness);
  tearDown(() => AppColors.brightness = saved);

  /// Every accent token, resolved under the active brightness.
  Map<String, Color> accents() => {
    'kLime': kLime,
    'kBlue': kBlue,
    'kCyan': kCyan,
    'kPink': kPink,
    'kGold': kGold,
    'kPurple': kPurple,
    'kGreen': kGreen,
    'kOrange': kOrange,
  };

  Map<String, Color> fills() => {
    'lime': ChartFill.lime,
    'blue': ChartFill.blue,
    'cyan': ChartFill.cyan,
    'pink': ChartFill.pink,
    'gold': ChartFill.gold,
    'purple': ChartFill.purple,
    'green': ChartFill.green,
    'orange': ChartFill.orange,
  };

  for (final mode in [Brightness.dark, Brightness.light]) {
    final name = mode == Brightness.dark ? 'dark' : 'light';

    group('$name mode', () {
      setUp(() => AppColors.brightness = mode);

      test('every accent is readable as text on the card', () {
        // Accents carry labels, values and icons, so the gate is the WCAG
        // text floor rather than the graphical-object one.
        accents().forEach((token, colour) {
          expect(
            contrast(colour, AppColors.surface),
            greaterThanOrEqualTo(4.5),
            reason:
                '$token is ${contrast(colour, AppColors.surface).toStringAsFixed(2)}:1 '
                'on the card — under the 4.5:1 text floor',
          );
        });
      });

      test('every chart fill sits inside the lightness band', () {
        // Outside this band a large fill either glares against a dark card or
        // washes out against a light one. This is the check the old palette
        // failed, at L 0.75-0.88.
        final lo = mode == Brightness.dark ? 0.48 : 0.43;
        final hi = mode == Brightness.dark ? 0.67 : 0.77;
        fills().forEach((token, colour) {
          expect(
            lightness(colour),
            inInclusiveRange(lo, hi),
            reason:
                'ChartFill.$token is at L ${lightness(colour).toStringAsFixed(3)}, '
                'outside the $lo-$hi band for $name surfaces',
          );
        });
      });

      test('every chart fill still reads as a hue, not as grey', () {
        fills().forEach((token, colour) {
          expect(
            chroma(colour),
            greaterThanOrEqualTo(0.10),
            reason:
                'ChartFill.$token has chroma '
                '${chroma(colour).toStringAsFixed(3)} — it will read grey and '
                'stop telling series apart',
          );
        });
      });

      test('every chart fill clears the graphical-object contrast floor', () {
        fills().forEach((token, colour) {
          expect(
            contrast(colour, AppColors.surface),
            greaterThanOrEqualTo(3.0),
            reason: 'ChartFill.$token is invisible on the card',
          );
        });
      });

      // Each entry is a set of fills that share ONE chart, so every pair of
      // them can end up side by side. Colour-blind separation has to hold
      // across all of them, not just neighbours.
      final coOccurring = {
        'readiness rings': ['lime', 'cyan', 'pink'],
        'calorie-status bars': ['green', 'gold', 'pink'],
        'macro donut': ['lime', 'blue', 'orange'],
      };

      coOccurring.forEach((chart, tokens) {
        test('$chart stays separable for colour-blind readers', () {
          final f = fills();
          for (var i = 0; i < tokens.length; i++) {
            for (var j = i + 1; j < tokens.length; j++) {
              final a = f[tokens[i]]!, b = f[tokens[j]]!;
              for (final kind in ['protan', 'deutan']) {
                expect(
                  deltaE(a, b, kind),
                  greaterThanOrEqualTo(6.0),
                  reason:
                      '${tokens[i]} and ${tokens[j]} collapse to '
                      '${deltaE(a, b, kind).toStringAsFixed(1)} under $kind',
                );
              }
              // Full-colour readers need the pair distinct too; this floor is
              // not excused by direct labels.
              expect(
                deltaE(a, b),
                greaterThanOrEqualTo(15.0),
                reason:
                    '${tokens[i]} and ${tokens[j]} are only '
                    '${deltaE(a, b).toStringAsFixed(1)} apart in normal vision',
              );
            }
          }
        });
      });

      test('chart surfaces are visible but stay recessive', () {
        // kChartEmpty marks "nothing logged that day" — it has to read as a
        // mark. The old code used kBgHighlight at 1.23:1, which read as
        // nothing at all, so an unlogged day looked like a missing bar.
        final surface = AppColors.surface;
        expect(
          contrast(over(kChartEmpty, surface), surface),
          greaterThan(contrast(over(kChartTrack, surface), surface)),
          reason: 'the empty-day mark must out-read the track behind it',
        );
        for (final chrome in [kChartTrack, kChartGrid]) {
          expect(
            contrast(over(chrome, surface), surface),
            lessThan(2.0),
            reason: 'chrome must not compete with the data',
          );
        }
      });

      test('de-emphasised series members stay visible', () {
        // These are the two that regressed under the old alpha-fade: purple
        // measured 1.8:1 and cyan 2.7:1 against the card, so the older bars in
        // the strength and volume charts were invisible on screen.
        for (final entry in {
          'purple': ChartFill.purple,
          'cyan': ChartFill.cyan,
        }.entries) {
          final muted = chartMuted(entry.value);
          expect(
            contrast(muted, AppColors.surface),
            greaterThanOrEqualTo(3.0),
            reason:
                'chartMuted(${entry.key}) is '
                '${contrast(muted, AppColors.surface).toStringAsFixed(2)}:1 — '
                'it disappears into the card',
          );
        }
      });
    });
  }

  group('the glow is gentler on a light surface', () {
    // A glow on near-black behaves like light: it adds brightness and falls
    // away into the background. On white it has nowhere brighter to go, so
    // the same alpha only darkens and tints — it stops reading as a glow and
    // starts reading as a coloured smudge. Nothing else in the suite can see
    // this, because it is a paint value rather than a layout or a contrast.
    test('light mode uses a weaker, tighter halo than dark', () {
      AppColors.brightness = Brightness.dark;
      final darkAlpha = kGlowAlpha, darkBlur = kGlowBlurRatio;
      AppColors.brightness = Brightness.light;
      final lightAlpha = kGlowAlpha, lightBlur = kGlowBlurRatio;

      expect(
        lightAlpha,
        lessThan(darkAlpha),
        reason: 'a light-mode glow at dark-mode strength reads as a stain',
      );
      expect(
        lightBlur,
        lessThanOrEqualTo(darkBlur),
        reason: 'a wider blur spreads the tint over more of a light surface',
      );
    });

    test('the halo stays a hint in both themes, never a fill', () {
      for (final mode in [Brightness.dark, Brightness.light]) {
        AppColors.brightness = mode;
        expect(
          kGlowAlpha,
          inExclusiveRange(0.0, 0.5),
          reason: 'a glow past ~0.5 is a filled disc, not a halo',
        );
      }
    });
  });

  group('the tab accents read as one family', () {
    // Seven accents appeared on a single screen and each tab repainted the
    // chrome from a 232-degree spread of the wheel, which is what made the
    // app look busy rather than designed.
    List<Color> tabs() => [kBrand, kTabScan, kTabBody, kTabTrain];

    /// OKLCH hue, degrees.
    double hueOf(Color c) {
      final lab = oklabOf(linearRgb(c));
      final h = math.atan2(lab[2], lab[1]) * 180 / math.pi;
      return h < 0 ? h + 360 : h;
    }

    for (final mode in [Brightness.dark, Brightness.light]) {
      final name = mode == Brightness.dark ? 'dark' : 'light';

      test('$name: every tab accent is one cool hue run', () {
        AppColors.brightness = mode;
        final hues = tabs().map(hueOf).toList()..sort();
        // Teal through indigo. Anything outside this is a hue from the
        // chart palette leaking back into the app's chrome.
        for (final h in hues) {
          expect(
            h,
            inInclusiveRange(180, 310),
            reason: 'a tab accent at ${h.toStringAsFixed(0)}deg is not cool',
          );
        }
        expect(
          hues.last - hues.first,
          lessThanOrEqualTo(110),
          reason:
              'tab accents span ${(hues.last - hues.first).toStringAsFixed(0)}'
              'deg — that is a rainbow, not a family',
        );
      });

      test('$name: every tab accent is readable on its own surface', () {
        AppColors.brightness = mode;
        for (final c in tabs()) {
          expect(contrast(c, AppColors.surface), greaterThanOrEqualTo(4.5));
        }
      });

      test('$name: the primary button label is readable on the brand', () {
        // Neither black nor white clears 4.5:1 on both themes' blue, so the
        // label colour has to flip with the theme.
        AppColors.brightness = mode;
        expect(contrast(kOnBrand, kBrand), greaterThanOrEqualTo(4.5));
      });
    }
  });

  test('the two themes actually differ', () {
    AppColors.brightness = Brightness.dark;
    final darkAccents = accents();
    final darkFills = fills();
    AppColors.brightness = Brightness.light;
    final lightAccents = accents();
    final lightFills = fills();

    // A token that resolves the same in both modes has not been given a light
    // step, which is how the palette drifted out of band in the first place.
    expect(
      darkFills.keys.where((k) => darkFills[k] != lightFills[k]).length,
      darkFills.length,
      reason: 'every chart fill needs its own step per mode',
    );
    expect(
      darkAccents.keys.where((k) => darkAccents[k] != lightAccents[k]).length,
      darkAccents.length,
      reason: 'every accent needs its own step per mode',
    );
  });
}
