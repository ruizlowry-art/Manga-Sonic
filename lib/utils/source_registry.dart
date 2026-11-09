class SourceRegistry {
  /// Map of built-in source IDs to their display names.
  static const Map<String, String> _displayNames = {
    'asura': 'Asura Scans',
    'asuracomic': 'Asura Scans',
    'manhuatop': 'ManhuaTop',
    'manhuaplus': 'Manhua Plus',
  };

  /// List of built-in source IDs.
  static const List<String> sourceIds = [
    'asuracomic',
    'manhuatop',
    'manhuaplus',
  ];

  /// Gets the display name for a source ID, falling back to upper-cased ID if not found.
  static String getDisplayName(String sourceId) {
    return _displayNames[sourceId] ?? sourceId.toUpperCase();
  }
}
