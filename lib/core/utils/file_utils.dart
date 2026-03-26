import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  static const MethodChannel _fileSaverChannel = MethodChannel('peerdrop/file_saver');

  static Future<File> saveFile(List<Uint8List> chunks, {required String fileName}) async {
    final bytes = Uint8List.fromList(chunks.expand((chunk) => chunk).toList());
    final sanitizedName = fileName.trim().isEmpty
        ? 'received_file.bin'
        : fileName.replaceAll(RegExp(r'[\\/]+'), '_');
    final safeName = '${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';

    if (Platform.isAndroid) {
      final savedPath = await _fileSaverChannel.invokeMethod<String>('saveToDownloads', {
        'fileName': safeName,
        'bytes': bytes,
      });

      if (savedPath == null || savedPath.isEmpty) {
        throw const FileSystemException('Unable to save file to Downloads');
      }

      return File(savedPath);
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$safeName');

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
