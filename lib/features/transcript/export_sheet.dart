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
              Navigator.pop(context);
              await exportService.shareText(entry.text);
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Save as PDF'),
            onTap: () async {
              Navigator.pop(context);
              await exportService.exportPdf(entry);
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Save to files'),
            onTap: () async {
              Navigator.pop(context);
              await exportService.saveTxt(entry.text);
            },
          ),
        ],
      ),
    );
  }
}
