import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TranscriptEntry {
  const TranscriptEntry({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.languageCode,
    required this.wordCount,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final String languageCode;
  final int wordCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'languageCode': languageCode,
      'wordCount': wordCount,
    };
  }

  factory TranscriptEntry.fromMap(Map<dynamic, dynamic> map) {
    return TranscriptEntry(
      id: map['id'] as String,
      text: map['text'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      languageCode: map['languageCode'] as String,
      wordCount: map['wordCount'] as int,
    );
  }
}

final transcriptBoxProvider = Provider<Box<dynamic>>(
  (ref) => Hive.box<dynamic>('transcripts'),
);

final transcriptProvider =
    NotifierProvider<TranscriptNotifier, List<TranscriptEntry>>(
      TranscriptNotifier.new,
    );

final transcriptByIdProvider = Provider.family<TranscriptEntry?, String>((
  ref,
  id,
) {
  return ref
      .watch(transcriptProvider)
      .where((entry) => entry.id == id)
      .firstOrNull;
});

class TranscriptNotifier extends Notifier<List<TranscriptEntry>> {
  @override
  List<TranscriptEntry> build() {
    final raw = ref.read(transcriptBoxProvider).get('entries');
    if (raw is List) {
      return raw.whereType<Map>().map(TranscriptEntry.fromMap).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return const [];
  }

  void add(TranscriptEntry entry) {
    state = [entry, ...state]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _persist();
  }

  void delete(String id) {
    state = state.where((entry) => entry.id != id).toList();
    _persist();
  }

  void restore(TranscriptEntry entry) {
    state = [entry, ...state]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _persist();
  }

  String exportJson() =>
      jsonEncode(state.map((entry) => entry.toMap()).toList());

  void _persist() {
    ref
        .read(transcriptBoxProvider)
        .put('entries', state.map((entry) => entry.toMap()).toList());
  }
}
