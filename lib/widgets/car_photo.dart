import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../services/photo_store.dart';

/// Myndir sem teknar eru í appinu fá slóð á forminu `local:<id>`.
const localPhotoScheme = 'local:';

bool isLocalPhoto(String? ref) => ref != null && ref.startsWith(localPhotoScheme);

/// Rétt [ImageProvider] fyrir mynd af bíl, hvort sem hún er af wiki eða tekin í appinu.
ImageProvider imageProviderFor(String ref) => isLocalPhoto(ref)
    ? LocalPhotoImage(ref.substring(localPhotoScheme.length))
    : CachedNetworkImageProvider(ref);

/// Mynd úr [PhotoStore], notuð eins og hver önnur mynd í Flutter.
@immutable
class LocalPhotoImage extends ImageProvider<LocalPhotoImage> {
  const LocalPhotoImage(this.id);

  final String id;

  @override
  Future<LocalPhotoImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(LocalPhotoImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await PhotoStore.instance.read(id);
    if (bytes == null || bytes.isEmpty) throw StateError('Myndin $id fannst ekki');
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is LocalPhotoImage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
