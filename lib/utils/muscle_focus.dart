/// Which muscles get flagged as FOCUS areas, and which as "OK, maintain".
///
/// FOCUS is a claim about how developed a muscle is. Only a physique scan
/// measures that, so the flags are scan-only by design.
///
/// The BODY tab falls back to 30-day training-volume balance when there's no
/// scan, but that number means something different: a muscle's share of your
/// training relative to your most-trained one. Feeding it through the same
/// "below 7 out of 10 is weak" rule told people who had never scanned that
/// their arms and core were lagging, when all it meant was that they had
/// trained chest more — and with no logged workouts at all every share is 0,
/// so it flagged two groups essentially at random.
library;

/// Indices to flag, given [scoresHighToLow] sorted strongest first.
///
/// Returns empty sets when [fromScan] is false: without a scan there is no
/// evidence about development, so nothing is claimed.
({Set<int> lagging, Set<int> maintain}) focusFlags({
  required List<double> scoresHighToLow,
  required bool fromScan,
  int maxFlagged = 2,
  double weakBelow = 7,
}) {
  if (!fromScan || scoresHighToLow.isEmpty) {
    return (lagging: <int>{}, maintain: <int>{});
  }

  final lagging = <int>{};
  final maintain = <int>{};
  final n = scoresHighToLow.length;

  for (var i = n - 1; i >= 0 && lagging.length < maxFlagged; i--) {
    if (scoresHighToLow[i] < weakBelow) {
      lagging.add(i);
    } else if (i >= n - maxFlagged && n > maxFlagged) {
      // Ranks lowest but is objectively strong — maintain it, don't "fix" it.
      maintain.add(i);
    }
  }
  return (lagging: lagging, maintain: maintain);
}
