class PersonalLexiconEntry {
  const PersonalLexiconEntry({
    required this.id,
    required this.spokenForm,
    required this.writtenForm,
    this.enabled = true,
  });

  final String id;
  final String spokenForm;
  final String writtenForm;
  final bool enabled;

  PersonalLexiconEntry copyWith({
    String? id,
    String? spokenForm,
    String? writtenForm,
    bool? enabled,
  }) {
    return PersonalLexiconEntry(
      id: id ?? this.id,
      spokenForm: spokenForm ?? this.spokenForm,
      writtenForm: writtenForm ?? this.writtenForm,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'spokenForm': spokenForm,
      'writtenForm': writtenForm,
      'enabled': enabled,
    };
  }

  factory PersonalLexiconEntry.fromMap(Map<dynamic, dynamic> map) {
    return PersonalLexiconEntry(
      id: map['id'] as String? ?? '',
      spokenForm: map['spokenForm'] as String? ?? '',
      writtenForm: map['writtenForm'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? true,
    );
  }
}

String applyPersonalLexicon(String value, List<PersonalLexiconEntry> entries) {
  var normalized = value;
  final activeEntries =
      entries
          .where(
            (entry) =>
                entry.enabled &&
                entry.spokenForm.trim().isNotEmpty &&
                entry.writtenForm.trim().isNotEmpty,
          )
          .toList()
        ..sort(
          (left, right) =>
              right.spokenForm.length.compareTo(left.spokenForm.length),
        );

  for (final entry in activeEntries) {
    normalized = _replaceEntry(normalized, entry);
  }
  return normalized;
}

String _replaceEntry(String value, PersonalLexiconEntry entry) {
  final spoken = entry.spokenForm.trim();
  final written = entry.writtenForm.trim();
  if (spoken.isEmpty || written.isEmpty) {
    return value;
  }

  if (_usesLiteralReplacement(spoken)) {
    return value.replaceAll(spoken, written);
  }

  final pattern = RegExp(
    '(?<![A-Za-z0-9_])${RegExp.escape(spoken)}(?![A-Za-z0-9_])',
    caseSensitive: false,
  );
  return value.replaceAllMapped(pattern, (_) => written);
}

bool _usesLiteralReplacement(String value) {
  return RegExp(r'[\u4E00-\u9FFF]').hasMatch(value) ||
      value.contains(' ') ||
      value.contains('-');
}
