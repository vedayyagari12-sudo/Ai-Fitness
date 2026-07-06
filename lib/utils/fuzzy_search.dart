int levenshtein(String a, String b) {
  final s = a.toLowerCase();
  final t = b.toLowerCase();
  if (s == t) return 0;
  if (s.isEmpty) return t.length;
  if (t.isEmpty) return s.length;
  final dp = List.generate(s.length + 1, (i) => List.filled(t.length + 1, 0));
  for (int i = 0; i <= s.length; i++) {
    dp[i][0] = i;
  }
  for (int j = 0; j <= t.length; j++) {
    dp[0][j] = j;
  }
  for (int i = 1; i <= s.length; i++) {
    for (int j = 1; j <= t.length; j++) {
      final cost = s[i - 1] == t[j - 1] ? 0 : 1;
      dp[i][j] = [
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost,
      ].reduce((a, b) => a < b ? a : b);
    }
  }
  return dp[s.length][t.length];
}

List<String> topFuzzyMatches(
  String query,
  List<String> candidates, {
  int limit = 5,
}) {
  if (query.isEmpty) return [];
  final q = query.toLowerCase();
  final scored = candidates.map((c) {
    final cl = c.toLowerCase();
    final dist = levenshtein(q, cl);
    final bonus = cl.contains(q) ? -1 : 0;
    return (c, dist + bonus);
  }).toList()..sort((a, b) => a.$2.compareTo(b.$2));
  return scored.take(limit).map((e) => e.$1).toList();
}

String titleCaseExercise(String name) {
  return name
      .trim()
      .split(' ')
      .map(
        (w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');
}
