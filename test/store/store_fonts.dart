import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Real fonts for the store-asset renders.
///
/// flutter_test ships a stub font that draws every glyph as a filled box, so
/// an unprepared golden renders headings and numbers as solid white bars —
/// fine for layout assertions, useless for a screenshot someone will look at.
///
/// Roboto is taken from the Flutter SDK's own material_fonts cache, which is
/// the same family Android uses as its platform default, so body text matches
/// what the app draws on a device.
///
/// Inter is what the app asks for on its stat numbers (GoogleFonts.inter).
/// google_fonts fetches it over the network at runtime, which a test has no
/// business doing, so runtime fetching is switched off and the Inter family
/// name is satisfied with Roboto instead. Both are neutral grotesques at
/// similar proportions, so the numbers read correctly — but this is a
/// substitution, not the shipped face, and the digits are very slightly
/// different in shape from what a device draws.
const _fontDir = 'C:/flutter/bin/cache/artifacts/material_fonts';

Future<void> loadStoreFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Left TRUE deliberately. With it false, google_fonts THROWS when a family
  // is missing from the app's own assets, regardless of what FontLoader has
  // registered. Left true it attempts a fetch, fails harmlessly against
  // flutter_test's mock HttpClient, logs a line, and the family name then
  // resolves to the real font registered below.
  GoogleFonts.config.allowRuntimeFetching = true;

  // flutter_test installs a mock HttpClient that fails every request, and
  // google_fonts RETHROWS a failed fetch rather than falling back — so with
  // the mock in place the render dies on the first Outfit glyph. Clearing the
  // override restores the real client for this render only, letting
  // google_fonts pull the genuine Outfit and Inter files it would use on a
  // device. This is a screenshot tool, not a unit test; it is the one place
  // in this suite where real network access is the correct behaviour.
  HttpOverrides.global = null;

  // google_fonts caches each download to the app support directory, which
  // has no plugin implementation under flutter_test — every fetch then dies
  // with MissingPluginException. Point it at the system temp dir.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );

  const weights = {
    'roboto-regular.ttf': FontWeight.w400,
    'roboto-medium.ttf': FontWeight.w500,
    'roboto-bold.ttf': FontWeight.w700,
    'roboto-black.ttf': FontWeight.w900,
  };

  // Outfit is the app's display face and Inter its number face; both come
  // from google_fonts, which fetches over the network at runtime. A test must
  // not do that, so fetching is off and both family names are satisfied with
  // Roboto. The layout, weights and sizes are the app's own; only the letter
  // shapes differ slightly from a device build.
  final roboto = FontLoader('Roboto');
  for (final file in weights.keys) {
    roboto.addFont(Future.value(_bytes(file)));
  }
  await roboto.load();

  // WeekStrip prints a literal emoji in its streak label. Android supplies a
  // system emoji font; the test engine supplies none, so the glyph lands as a
  // tofu box in the middle of a store screenshot. Registering an emoji face
  // under the same family names lets Skia fall back to it for that codepoint.
  const emoji = 'C:/Windows/Fonts/seguiemj.ttf';
  if (File(emoji).existsSync()) {
    final data = ByteData.view(
      Uint8List.fromList(File(emoji).readAsBytesSync()).buffer,
    );
    for (final family in ['Roboto', 'Outfit', 'Inter']) {
      final loader = FontLoader(family)..addFont(Future.value(data));
      await loader.load();
    }
  }

  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(_bytes('materialicons-regular.otf')));
  await icons.load();

  // Pull every weight the app asks for NOW, while we are outside a
  // testWidgets body, and wait for all of them to land.
  //
  // google_fonts fetches lazily, on the first build that uses a style. Left
  // to do that during the render, the in-flight request outlives the widget
  // tree and the binding fails the test with "A Timer is still pending even
  // after the widget tree was disposed" — the shot never gets written.
  for (final weight in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
    FontWeight.w900,
  ]) {
    GoogleFonts.outfit(fontWeight: weight);
    GoogleFonts.inter(fontWeight: weight);
  }
  await GoogleFonts.pendingFonts();
}

ByteData _bytes(String file) {
  final b = File('$_fontDir/$file').readAsBytesSync();
  return ByteData.view(Uint8List.fromList(b).buffer);
}
