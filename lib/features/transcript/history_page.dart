import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets/ink_wash_background.dart';
import 'transcript_card.dart';
import 'transcript_provider.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  late final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transcripts = ref.watch(transcriptProvider);
    final filtered = _filterTranscripts(transcripts, _query);

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
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _query = value;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: '搜索稿件内容、语言或术语',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _query.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _query = '';
                                        });
                                      },
                                      icon: const Icon(Icons.close),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _query.trim().isEmpty
                                ? '共 ${transcripts.length} 条语音稿，支持按关键词快速找回。'
                                : '已命中 ${filtered.length} 条结果。',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (filtered.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off_outlined,
                              size: 38,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '没有找到匹配内容',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '换个关键词试试，比如联系人、项目名、产品名或一段你说过的话。',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (entry) => Padding(
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
                            ref
                                .read(transcriptProvider.notifier)
                                .delete(entry.id);
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
                            onTap: () =>
                                context.push('/transcript/${entry.id}'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  List<TranscriptEntry> _filterTranscripts(
    List<TranscriptEntry> transcripts,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return transcripts;
    }

    return transcripts.where((entry) {
      return entry.text.toLowerCase().contains(normalized) ||
          entry.languageCode.toLowerCase().contains(normalized);
    }).toList();
  }
}
