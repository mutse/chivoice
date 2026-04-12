import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/theme.dart';
import 'export_service.dart';
import 'export_sheet.dart';
import 'transcript_provider.dart';

class TranscriptDetailSheet extends ConsumerWidget {
  const TranscriptDetailSheet({super.key, required this.transcriptId});

  final String transcriptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(transcriptByIdProvider(transcriptId));

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kSurface2,
              borderRadius: BorderRadius.circular(28),
            ),
            child: entry == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Transcript not found'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: context.pop,
                        child: const Text('Close'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Transcript',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: context.pop,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Text(
                        '${entry.languageCode} · ${entry.wordCount} words',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 340),
                        child: SingleChildScrollView(
                          child: Text(
                            entry.text,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: kSurface2,
                            builder: (context) => ExportSheet(
                              entry: entry,
                              exportService: ref.read(exportServiceProvider),
                            ),
                          );
                        },
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Export'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
