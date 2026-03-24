import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class FileUtils {
  static Future<File> saveFile(List<Uint8List> chunks, {required String fileName}) async {
    final bytes = Uint8List.fromList(chunks.expand((chunk) => chunk).toList());

    final dir = await getApplicationDocumentsDirectory();
    final sanitizedName = fileName.trim().isEmpty
        ? 'received_file.bin'
        : fileName.replaceAll(RegExp(r'[\\/]+'), '_');
    final file = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName');

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
