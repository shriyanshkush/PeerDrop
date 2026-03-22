import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  static Future<File> saveFile(List<Uint8List> chunks) async {
    final bytes = Uint8List.fromList(chunks.expand((e) => e).toList());

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/file_${DateTime.now().millisecondsSinceEpoch}.bin');

    await file.writeAsBytes(bytes);
    return file;
  }
}
