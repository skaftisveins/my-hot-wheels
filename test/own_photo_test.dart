import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:hot_wheels_safn/data/collection_store.dart';
import 'package:hot_wheels_safn/models/car.dart';
import 'package:hot_wheels_safn/services/photo_store.dart';
import 'package:hot_wheels_safn/widgets/car_photo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Uint8List> tinyPng() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
      .drawRect(const Rect.fromLTWH(0, 0, 8, 4), Paint()..color = const Color(0xFFD32F2F));
  final image = await recorder.endRecording().toImage(8, 4);
  return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PhotoStore.instance = MemoryPhotoStore();
  });

  test('own photo is shown before the wiki photo and survives a JSON round trip', () {
    final car = Car(
      id: 'a',
      name: 'Twin Mill',
      addedAt: DateTime(2026),
      imageUrl: 'https://img.test/wiki.png',
      ownPhoto: 'p1',
    );
    expect(car.displayImage, 'local:p1');
    expect(Car.fromJson(car.toJson()).ownPhoto, 'p1');
    expect(car.copyWith(ownPhoto: null).displayImage, 'local:p1');
    expect(Car(id: 'b', name: 'X', addedAt: DateTime(2026), imageUrl: 'u').displayImage, 'u');
  });

  test('setOwnPhoto switches between own photo and the wiki photo', () async {
    final store = CollectionStore(await SharedPreferences.getInstance());
    await store.add(Car(id: 'a', name: 'Twin Mill', addedAt: DateTime(2026), imageUrl: 'u'));

    await store.setOwnPhoto('a', 'p1');
    expect(store.byId('a')!.displayImage, 'local:p1');

    await store.setOwnPhoto('a', null);
    expect(store.byId('a')!.ownPhoto, isNull);
    expect(store.byId('a')!.displayImage, 'u');
  });

  test('image references pick the right provider', () {
    expect(imageProviderFor('local:abc'), const LocalPhotoImage('abc'));
    expect(isLocalPhoto('local:abc'), isTrue);
    expect(isLocalPhoto('https://img.test/a.png'), isFalse);
  });

  testWidgets('photos taken in the app load from the photo store', (tester) async {
    await tester.runAsync(() async {
      await PhotoStore.instance.write('p1', await tinyPng());
    });
    final provider = imageProviderFor('local:p1');
    ui.Image? loaded;
    await tester.runAsync(() async {
      final stream = provider.resolve(ImageConfiguration.empty);
      final done = Completer<void>();
      stream.addListener(
        ImageStreamListener((info, _) {
          loaded = info.image;
          done.complete();
        }),
      );
      await done.future;
    });
    expect(loaded!.width, 8);
    expect(loaded!.height, 4);
  });
}
