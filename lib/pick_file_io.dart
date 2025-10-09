import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<(String, Uint8List)?> pickFileUniversal({
  required List<String> allowedExtensions,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowMultiple: false,
    withData: true,
    allowedExtensions: allowedExtensions,
  );
  if (result == null || result.files.isEmpty) return null;

  final f = result.files.single;
  Uint8List? bytes = f.bytes;
  if (bytes == null && f.readStream != null) {
    final chunks = <int>[];
    await for (final chunk in f.readStream!) {
      chunks.addAll(chunk);
    }
    bytes = Uint8List.fromList(chunks);
  }
  if (bytes == null) return null;
  return (f.name, bytes);
}
