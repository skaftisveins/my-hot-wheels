import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../photo_store.dart';

PhotoStore createPlatformPhotoStore() => _IndexedDbPhotoStore();

class _IndexedDbPhotoStore implements PhotoStore {
  static const _name = 'bilasafnid';
  static const _storeName = 'photos';
  Future<web.IDBDatabase>? _db;

  Future<web.IDBDatabase> get _database => _db ??= _open();

  Future<web.IDBDatabase> _open() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_name, 1);
    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_storeName)) db.createObjectStore(_storeName);
    }).toJS;
    request.onsuccess = ((web.Event _) => completer.complete(
      request.result as web.IDBDatabase,
    )).toJS;
    request.onerror = ((web.Event _) => completer.completeError(
      StateError('Gat ekki opnað myndageymsluna: ${request.error?.message}'),
    )).toJS;
    return completer.future;
  }

  Future<web.IDBObjectStore> _store(String mode) async =>
      (await _database).transaction(_storeName.toJS, mode).objectStore(_storeName);

  Future<JSAny?> _run(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) => completer.complete(request.result)).toJS;
    request.onerror = ((web.Event _) => completer.completeError(
      StateError('Villa í myndageymslu: ${request.error?.message}'),
    )).toJS;
    return completer.future;
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    await _run((await _store('readwrite')).put(bytes.toJS, id.toJS));
  }

  @override
  Future<Uint8List?> read(String id) async {
    final result = await _run((await _store('readonly')).get(id.toJS));
    return result == null ? null : (result as JSUint8Array).toDart;
  }

  @override
  Future<void> delete(String id) async {
    await _run((await _store('readwrite')).delete(id.toJS));
  }
}
