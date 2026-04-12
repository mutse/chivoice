import 'package:flutter/material.dart';

import 'export_service.dart';
import 'transcript_provider.dart';

class ExportSheet extends StatelessWidget {
  const ExportSheet({
    super.key,
    required this.entry,
    required this.exportService,
  });

  final TranscriptEntry entry;
  final ExportService exportService;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () async {
              await _runAction(
                context,
                label: 'Shared transcript',
                action: () => exportService.shareText(entry.text),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Save as PDF'),
            onTap: () async {
              await _runAction(
                context,
                label: 'Opened PDF export',
                action: () => exportService.exportPdf(entry),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Save to files'),
            onTap: () async {
              await _runAction(
                context,
                label: 'Saved text file',
                action: () => exportService.saveTxt(entry.text),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context, {
    required String label,
    required Future<void> Function() action,
  }) async {
    Navigator.pop(context);
    try {
      await action();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(label)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
    }
  }
}
