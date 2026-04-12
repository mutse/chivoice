import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'transcript_provider.dart';

typedef DirectoryLoader = Future<Directory> Function();
typedef ShareFiles = Future<void> Function(List<XFile> files, String subject);
typedef PdfPrinter = Future<void> Function(List<int> bytes);

abstract class ExportService {
  Future<void> shareText(String text);
  Future<File> saveTxt(String text);
  Future<void> exportPdf(TranscriptEntry entry);
}

class SystemExportService implements ExportService {
  SystemExportService({
    DirectoryLoader? documentsDirectory,
    DirectoryLoader? temporaryDirectory,
    ShareFiles? shareFiles,
    PdfPrinter? pdfPrinter,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _shareFiles =
           shareFiles ??
           ((files, subject) async {
             await SharePlus.instance.share(
               ShareParams(files: files, subject: subject),
             );
           }),
       _pdfPrinter =
           pdfPrinter ??
           ((bytes) async {
             await Printing.layoutPdf(
               onLayout: (_) async => Uint8List.fromList(bytes),
             );
           });

  final DirectoryLoader _documentsDirectory;
  final DirectoryLoader _temporaryDirectory;
  final ShareFiles _shareFiles;
  final PdfPrinter _pdfPrinter;

  @override
  Future<File> saveTxt(String text) async {
    final dir = await _documentsDirectory();
    final name = 'transcript_${DateTime.now().millisecondsSinceEpoch}.txt';
    final file = File('${dir.path}/$name');
    return file.writeAsString(text);
  }

  @override
  Future<void> shareText(String text) async {
    final dir = await _temporaryDirectory();
    final file = File('${dir.path}/transcript.txt');
    await file.writeAsString(text);
    await _shareFiles([XFile(file.path)], 'Transcript');
  }

  @override
  Future<void> exportPdf(TranscriptEntry entry) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(40),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Transcript',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${entry.createdAt.toLocal()} · ${entry.languageCode} · ${entry.wordCount} words',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
            ),
            pw.Divider(height: 24),
            pw.Text(
              entry.text,
              style: const pw.TextStyle(fontSize: 13, lineSpacing: 4),
            ),
          ],
        ),
      ),
    );
    await _pdfPrinter(await doc.save());
  }
}
