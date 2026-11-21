import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../photo_store.dart';

PhotoStore createPlatformPhotoStore() => _FilePhotoStore();

class _FilePhotoStore implements PhotoStore {
  Future<File> _file(String id) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/photos');
    await dir.create(recursive: true);
    return File('${dir.path}/$id');
  }

  @override
  Future<void> write(String id, Uint8List bytes) async => (await _file(id)).writeAsBytes(bytes);

  @override
  Future<Uint8List?> read(String id) async {
    final file = await _file(id);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
  }
}
