import 'package:flutter/material.dart';

import '../shared/theme.dart';
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
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kPanel,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kPaperLine),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('发送与导出', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享文本'),
              onTap: () async {
                await _runAction(
                  context,
                  label: '已调起分享',
                  action: () => exportService.shareText(entry.text),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('导出 PDF'),
              onTap: () async {
                await _runAction(
                  context,
                  label: '已打开 PDF 导出',
                  action: () => exportService.exportPdf(entry),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('保存 TXT'),
              onTap: () async {
                await _runAction(
                  context,
                  label: '已保存文本文件',
                  action: () => exportService.saveTxt(entry.text),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
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
      ).showSnackBar(SnackBar(content: Text('导出失败：$error')));
    }
  }
}
