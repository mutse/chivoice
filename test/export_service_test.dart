import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:chivoice/features/transcript/export_service.dart';
import 'package:chivoice/features/transcript/transcript_provider.dart';

void main() {
  group('SystemExportService', () {
    test('saveTxt writes correct content', () async {
      final dir = await Directory.systemTemp.createTemp('voxa_export_test');
      final service = SystemExportService(documentsDirectory: () async => dir);

      final file = await service.saveTxt('hello world');

      expect(await file.readAsString(), 'hello world');
    });

    test('shareText constructs correct XFile', () async {
      final dir = await Directory.systemTemp.createTemp('voxa_share_test');
      late List<XFile> captured;
      late String subject;
      final service = SystemExportService(
        temporaryDirectory: () async => dir,
        shareFiles: (files, providedSubject) async {
          captured = files;
          subject = providedSubject;
        },
      );

      await service.shareText('share me');

      expect(captured.single.path, '${dir.path}/transcript.txt');
      expect(subject, 'Transcript');
      expect(await File(captured.single.path).readAsString(), 'share me');
    });

    test('exportPdf delegates bytes to printer', () async {
      List<int>? bytes;
      final service = SystemExportService(
        pdfPrinter: (value) async => bytes = value,
      );

      await service.exportPdf(
        TranscriptEntry(
          id: '1',
          text: 'Hello',
          createdAt: DateTime(2026, 4, 12),
          languageCode: 'en-US',
          wordCount: 1,
        ),
      );

      expect(bytes, isNotNull);
      expect(bytes, isNotEmpty);
    });
  });
}
