import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets/ink_wash_background.dart';
import 'transcript_card.dart';
import 'transcript_provider.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcripts = ref.watch(transcriptProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('稿库')),
      body: InkWashBackground(
        child: transcripts.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 42,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '还没有语音稿件',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '说完一段话后，识别结果会自动保存在这里，方便继续编辑或导出。',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                itemCount: transcripts.length,
                itemBuilder: (context, index) {
                  final entry = transcripts[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Dismissible(
                      key: ValueKey(entry.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD27C69),
                          borderRadius: BorderRadius.circular(24),
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
                            content: const Text('已删除一条稿件'),
                            action: SnackBarAction(
                              label: '撤销',
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
                        onTap: () => context.push('/transcript/${entry.id}'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
