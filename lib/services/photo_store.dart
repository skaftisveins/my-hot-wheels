import 'dart:typed_data';

import 'photos/photo_store_io.dart' if (dart.library.js_interop) 'photos/photo_store_web.dart';

/// Geymir myndir sem teknar eru í appinu, á tækinu sjálfu.
///
/// Í vafra er notaður gagnagrunnur vafrans (IndexedDB), sem rúmar miklu meira
/// en venjuleg vafrageymsla. Í uppsettu appi eru myndirnar skrár.
abstract class PhotoStore {
  static PhotoStore instance = createPlatformPhotoStore();

  Future<void> write(String id, Uint8List bytes);

  Future<Uint8List?> read(String id);

  Future<void> delete(String id);
}

/// Geymsla í minni, fyrir prófanir.
class MemoryPhotoStore implements PhotoStore {
  final photos = <String, Uint8List>{};

  @override
  Future<void> write(String id, Uint8List bytes) async => photos[id] = bytes;

  @override
  Future<Uint8List?> read(String id) async => photos[id];

  @override
  Future<void> delete(String id) async => photos.remove(id);
}
