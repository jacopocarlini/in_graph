import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;
import 'package:universal_html/html.dart' as html;

class FileExportService {
  static Future<void> saveStringFile({
    required String content,
    required String fileName,
    String? dialogTitle,
    String? extension,
  }) async {
    final bytes = utf8.encode(content);
    await saveBytesFile(
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
      dialogTitle: dialogTitle,
      extension: extension,
    );
  }

  static Future<void> saveBytesFile({
    required Uint8List bytes,
    required String fileName,
    String? dialogTitle,
    String? extension,
  }) async {
    if (kIsWeb) {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      return;
    }

    // CHANGED: Removed .platform
    final String? outputFile = await FilePicker.saveFile(
      dialogTitle: dialogTitle ?? 'Salva file',
      fileName: fileName,
      type: extension != null ? FileType.custom : FileType.any,
      allowedExtensions: extension != null ? [extension] : null,
    );

    if (outputFile != null) {
      final file = io.File(outputFile);
      await file.writeAsBytes(bytes);
    }
  }

  static Future<String?> pickAndReadFile({
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    // CHANGED: Removed .platform
    final result = await FilePicker.pickFiles(
      dialogTitle: dialogTitle ?? 'Seleziona file',
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        return utf8.decode(file.bytes!);
      } else if (file.path != null && !kIsWeb) {
        final f = io.File(file.path!);
        return await f.readAsString();
      }
    }
    return null;
  }
}