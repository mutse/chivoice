import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/theme.dart';
import 'export_service.dart';
import 'export_sheet.dart';
import 'transcript_card.dart';
import 'transcript_provider.dart';

final exportServiceProvider = Provider<ExportService>(
  (ref) => SystemExportService(),
);

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcripts = ref.watch(transcriptProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: Colors.transparent,
      ),
      body: transcripts.isEmpty
          ? const Center(
              child: Text(
                'Your transcripts will appear here.',
                style: TextStyle(color: kTextMuted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              itemCount: transcripts.length,
              itemBuilder: (context, index) {
                final entry = transcripts[index];
                return Dismissible(
                  key: ValueKey(entry.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                    ),
                  ),
                  confirmDismiss: (_) async => true,
                  onDismissed: (_) {
                    ref.read(transcriptProvider.notifier).delete(entry.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Transcript deleted'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            ref
                                .read(transcriptProvider.notifier)
                                .restore(entry);
                          },
                        ),
                      ),
                    );
                  },
                  child: TranscriptCard(
                    entry: entry,
                    onTap: () => _showDetail(context, ref, entry),
                  ),
                );
              },
            ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref, TranscriptEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface2,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transcript',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(entry.text, style: Theme.of(context).textTheme.bodyLarge),
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
        );
      },
    );
  }
}
