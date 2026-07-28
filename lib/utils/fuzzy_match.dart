/// Classic edit-distance algorithm (Levenshtein).
/// Used to fuzzy-match product names during vendor/cart matching,
/// so minor spelling variation ("tomatoe" vs "tomato") still matches.
int levenshteinDistance(String a, String b) {
  a = a.toLowerCase().trim();
  b = b.toLowerCase().trim();
  final m = a.length, n = b.length;
  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

  for (int i = 0; i <= m; i++) dp[i][0] = i;
  for (int j = 0; j <= n; j++) dp[0][j] = j;

  for (int i = 1; i <= m; i++) {
    for (int j = 1; j <= n; j++) {
      if (a[i - 1] == b[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1];
      } else {
        dp[i][j] = 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
            .reduce((x, y) => x < y ? x : y);
      }
    }
  }
  return dp[m][n];
}

/// Returns true if two product names are a likely match — either one
/// contains the other, or their edit distance is small relative to length.
bool isFuzzyMatch(String a, String b) {
  final aLower = a.toLowerCase().trim();
  final bLower = b.toLowerCase().trim();
  if (aLower.contains(bLower) || bLower.contains(aLower)) return true;
  final distance = levenshteinDistance(aLower, bLower);
  final threshold = (aLower.length * 0.3).ceil(); // allow ~30% char difference
  return distance <= threshold;
}