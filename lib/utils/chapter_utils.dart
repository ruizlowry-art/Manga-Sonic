class ChapterUtils {
  /// Compiled regex to extract decimal or integer numbers from strings.
  /// Pre-compiling this improves performance in sorting loops.
  static final RegExp _numRegex = RegExp(r'(\d+(\.\d+)?)');

  /// Extracts the chapter number as a double from a title string.
  /// Returns 0.0 if no number is found.
  static double extractNumber(String title) {
    final match = _numRegex.firstMatch(title);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  /// Compares two chapter titles numerically in ascending order.
  static int compareAscending(String a, String b) {
    final numA = extractNumber(a);
    final numB = extractNumber(b);
    return numA.compareTo(numB);
  }
}
