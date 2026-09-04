# Play Store listing assets

Upload these in Play Console under **Grow → Store presence → Main store listing**.

| File | Where it goes | Source |
|---|---|---|
| `01_app_icon_512.png` | App icon (512 x 512) | Composited from the real launcher icon |
| `02_feature_graphic_1024x500.png` | Feature graphic (1024 x 500) | Real icon + real Outfit face + kBrand |
| `03_screenshot_dashboard.png` | Phone screenshot | Rendered from the app's widgets (dark) |
| `04_screenshot_trends.png` | Phone screenshot | Rendered from the app's widgets (**light**) |
| `05_screenshot_food_scan.png` | Phone screenshot | **Real device capture** |
| `06_screenshot_physique_scan.png` | Phone screenshot | **Real device capture** |
| `07_screenshot_body.png` | Phone screenshot | **Real device capture** |
| `08_screenshot_workout.png` | Phone screenshot | **Real device capture** |
| `optional_scan_history_light.png` | *not in the set* | Real, sharp, but shows a fixed bug |

All screenshots are 1080 x 1920 (9:16). Play needs at least 2; six are here,
under the limit of 8.

## Dark and light

Four screenshots are the app's dark theme, one (`04`) is light. Real captures
keep whatever theme they were taken in.

The dark background is NOT flat black. Every tab wraps its body in
`AmbientBackground`, which paints `kPageGradient` — a vertical fade from a
blue-tinted `#1E2736` at the top through `#10131A` to `#0A0A0A`. An earlier
pass rendered onto flat `kBgDeep` and the result read as a different app. The
renderer now uses the real `AmbientBackground` widget, so this comes for free.

## The real captures

`05`-`08` are genuine screenshots of the running app with real logged data.
`tool/process_real_screenshots.py` prepares them:

- **Crops off the red Flutter DEBUG ribbon.** Measured per image, not assumed:
  9-12px on most, ~40px where the phone status bar is also present. Detection
  is confined to the far corner and to strongly saturated red — a wider test
  matched the warm tones in the food photo and would have cropped the header
  away. An earlier version *painted over* the corner instead and destroyed the
  BODY screen's "AUG 31" date chip; cropping cannot erase a control.
- **Trims the black window-border strips** the mirror capture leaves (up to
  15px). Left in, the padding step copies that black column outward and the
  shot gets a hard black band down one side.
- **Scales to fit and pads by edge replication.** Never an invented colour: the
  page gradient is horizontally uniform, so extending a row sideways is
  seamless.

**Known limitation:** `05`-`08` were captured from a phone-mirror window at
~390px wide, so upscaling to 1080 leaves them visibly softer than the rendered
shots. Upscaling cannot add detail back. Re-capturing these four natively on
the phone (Power + Volume Down gives 1080 x 2340) and re-running the script
would fix it — the script handles native captures already, as
`optional_scan_history_light.png` shows.

## How they were made, and what that means for accuracy

### The two rendered shots (`03`, `04`)

**Rendered by the real Flutter engine from the app's own widgets.** `ReadinessCard`, `TrendCard`, `FuelCard`/`MacroDonut`, `MuscleRadar`,
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
