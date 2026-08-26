/// One sentence synthesizing the three readiness rings into a single verdict.
///
/// The corner stats already show each ring's raw number; this doesn't repeat
/// them; it answers the question the numbers don't: "so how am I doing
/// overall?" Same job as [MacroSplit.takeaway] elsewhere in the app — turn a
/// handful of derived values into one plain-English line — kept as a
/// top-level function here since there is no accompanying data class to
/// attach it to.
///
/// [calories], [protein] and [sessions] are the same 0..1 progress values
/// backing the rings, already clamped by the caller (today_screen.dart).
String readinessTakeaway({
  required double calories,
  required double protein,
  required double sessions,
}) {
  // 0.98 rather than 1.0: the values are clamped upstream, but a ratio that
  // lands at 0.999999 from float division should still read as "done" —
  // requiring an exact 1.0 would make the message flicker between "done"
  // and "almost" for a target hit by a single gram or calorie.
  bool done(double v) => v >= 0.98;

  final cal = done(calories);
  final pro = done(protein);
  final ses = done(sessions);
  final doneCount = [cal, pro, ses].where((v) => v).length;

  if (doneCount == 3) {
    return 'Every box checked — full send today.';
  }

  if (doneCount == 0) {
    // Distinguish true zero (nothing logged) from merely short — "0 of 3"
    // reads as a fresh start, not a failure, this early in the day.
    final allZero = calories <= 0 && protein <= 0 && sessions <= 0;
    return allZero
        ? 'Fresh start — nothing logged yet today.'
        : 'Just getting going — 3 boxes still open.';
  }

  // Exactly one thing left names it specifically, since "2 of 3" is a
  // strictly less useful sentence than "log your protein" when the app
  // already knows which one it is.
  if (doneCount == 2) {
    if (!ses) return 'Fuel and protein done — just get a session in.';
    if (!cal) return 'Trained and fueled on protein — calories left to hit.';
    return 'Trained and calories hit — top up protein to finish.';
  }

  // Exactly one done, two open. One of the three guards below always fires —
  // doneCount == 1 guarantees it — so the trailing return is unreachable by
  // construction; it exists only because Dart can't prove that from three
  // independent booleans and still requires the function to be total.
  // No unicode checkmark glyph here — the WHOOP-style rings elsewhere in
  // this app (WeekStrip) draw a completion mark as an Icons.check_rounded
  // glyph, bundled with the app rather than fetched, for the same reason:
  // a raw ✓ character rendered as a tofu box under Inter during testing,
  // and a body-text string has no way to fall back to an icon font.
  if (ses) return 'Trained today — food is the rest of the job.';
  if (cal) return 'Calories on track — protein and training still open.';
  if (pro) return 'Protein on track — train and fuel to close it out.';

  return '1 of 3 today — keep going.';
}
