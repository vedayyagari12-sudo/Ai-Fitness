# Play Store listing assets

Upload these in Play Console under **Grow → Store presence → Main store listing**.

| File | Where it goes | Size |
|---|---|---|
| `01_app_icon_512.png` | App icon | 512 × 512 |
| `02_feature_graphic_1024x500.png` | Feature graphic | 1024 × 500 |
| `03_screenshot_dashboard.png` | Phone screenshots | 1080 × 1920 |
| `04_screenshot_trends.png` | Phone screenshots | 1080 × 1920 |
| `05_screenshot_physique_scan.png` | Phone screenshots | 1080 × 1920 |
| `06_screenshot_food_scan.png` | Phone screenshots | 1080 × 1920 |
| `07_screenshot_workout.png` | Phone screenshots | 1080 × 1920 |

Play needs at least 2 phone screenshots; 5 are here. All are 9:16, inside the
16:9–9:16 ratio band and the 320–3840 px per-side limits.

## How they were made, and what that means for accuracy

**The screenshots are rendered by the real Flutter engine from the app's own
widgets.** `ReadinessCard`, `TrendCard`, `FuelCard`/`MacroDonut`, `MuscleRadar`,
`WeekStrip` and `StreakChip` are the exact classes that run on a device, drawn
in the real dark theme, given sample data instead of a live account. They are
not redrawn mockups, so the rings, charts, colours, spacing and type are the
shipped ones.

What is *not* pixel-identical to a device:

- **The sample data is invented.** The numbers are plausible, not from a real
  account. Any screen shows data a real user could produce.
- **The header row and bottom nav** in these shots are laid out by the renderer
  to match the shipped chrome, rather than being the app's own scaffolding —
  the real ones need a live navigation stack.
- **No OS status bar.** Deliberate: inventing a fake carrier/battery row would
  be chrome the app does not own.
- **The physique-score, meal and workout panels** are built from the app's own
  theme tokens (`kHeroCardGradient`, `kGlassBorder`, `kLabelSmall`, `kStatHero`)
  rather than being the literal screen widgets, which need network results to
  build. The charts inside them are the real widgets.

If Play ever queries whether a screenshot depicts the real app: it does — same
engine, same widgets, same theme.

## Regenerating

Screenshots:

```
flutter test test/store/render_store_assets.dart --update-goldens
```

The file is deliberately **not** named `*_test.dart`, so it is skipped by a
normal `flutter test` run. It needs the network: it clears flutter_test's mock
HTTP client so google_fonts can fetch the real Outfit and Inter faces the app
ships. A unit-test suite has no business doing that, hence the separation.

Feature graphic:

```
python tool/make_feature_graphic.py
```

App icon — regenerate only if the launcher icon changes; it is composited from
`mipmap-xxxhdpi/ic_launcher_foreground.png` over `ic_launcher_background`
(`#0E1217`).

## Still needed for the listing

- **Tablet screenshots** (7" and 10") if you want the tablet form factors listed.
- **Short description** (80 chars) and **full description** (4000 chars).
- Play also asks for a **privacy policy URL** — that is `docs/privacy_policy.html`
  once GitHub Pages is enabled.
