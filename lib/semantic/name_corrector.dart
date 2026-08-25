// Pure Dart — no Flutter imports.

class NameCorrection {
  final String text;
  final List<String> mentioned;

  const NameCorrection(this.text, this.mentioned);
}

class NameCorrector {
  const NameCorrector();

  /// Slides a same-length window over [text] for each contact (length 2–4).
  /// - Exact match → record as mentioned, no replacement needed.
  /// - Levenshtein distance == 1 → replace window with contact, record mentioned.
  /// - Distance > 1 → skip.
  NameCorrection correct(String text, List<String> contacts) {
    var result = text;
    final mentioned = <String>[];

    for (final contact in contacts) {
      final len = contact.length;
      if (len < 2 || len > 4) continue; // only 2–4 char names

      final chars = _toCharList(result);
      if (chars.length < len) continue;

      final contactChars = _toCharList(contact);

      for (int i = 0; i <= chars.length - len; i++) {
        final window = chars.sublist(i, i + len);
        final dist = _levenshtein(window, contactChars);
        if (dist == 0) {
          // Exact match — record mentioned, no text change needed.
          if (!mentioned.contains(contact)) mentioned.add(contact);
          break;
        } else if (dist == 1) {
          // One-off typo — replace window with correct contact name.
          if (!mentioned.contains(contact)) mentioned.add(contact);
          final before = chars.sublist(0, i).join();
          final after = chars.sublist(i + len).join();
          result = before + contact + after;
          break;
        }
      }
    }

    return NameCorrection(result, mentioned);
  }

  /// Splits a string into individual characters.
  /// CJK characters are each a single rune, so rune-splitting is correct.
  static List<String> _toCharList(String s) =>
      s.runes.map(String.fromCharCode).toList();

  /// Classic DP Levenshtein distance between two character lists.
  static int _levenshtein(List<String> a, List<String> b) {
    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (i) => List.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) { dp[i][0] = i; }
    for (int j = 0; j <= n; j++) { dp[0][j] = j; }
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + _min3(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
        }
      }
    }
    return dp[m][n];
  }

  static int _min3(int a, int b, int c) =>
      a < b ? (a < c ? a : c) : (b < c ? b : c);
}
