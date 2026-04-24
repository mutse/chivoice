import 'package:flutter/material.dart';

import 'transcript_provider.dart';

class TranscriptCard extends StatelessWidget {
  const TranscriptCard({super.key, required this.entry, required this.onTap});

  final TranscriptEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = entry.text.length > 120
        ? '${entry.text.substring(0, 120)}...'
        : entry.text;
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        onTap: onTap,
        title: Text(
          preview,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(label: _relativeTime(entry.createdAt), color: primary),
              _Badge(label: entry.languageCode, color: primary),
              _Badge(label: '${entry.wordCount} 字', color: primary),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  static String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) {
      return '刚刚';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} 分钟前';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} 小时前';
    }
    return '${diff.inDays} 天前';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
