import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hot_wheels_safn/widgets/cutout.dart';

/// Býr til RGBA-mynd: [paint] fyrir punkta þar sem [inside] er satt, annars [background].
Uint8List draw(
  int w,
  int h,
  List<int> background,
  List<int> paint,
  bool Function(int x, int y) inside,
) {
  final bytes = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final c = inside(x, y) ? paint : background;
      final i = (y * w + x) * 4;
      bytes
        ..[i] = c[0]
        ..[i + 1] = c[1]
        ..[i + 2] = c[2]
        ..[i + 3] = 255;
    }
  }
  return bytes;
}

/// Bílslaga: búkur og tvö dekk (ekki fylltur kassi).
bool carShape(int x, int y) {
  final body = x >= 20 && x < 180 && y >= 40 && y < 75;
  final cabin = x >= 60 && x < 130 && y >= 22 && y < 40;
  bool wheel(int cx) => (x - cx) * (x - cx) + (y - 78) * (y - 78) < 15 * 15;
  return body || cabin || wheel(50) || wheel(150);
}

void main() {
  test('cuts a car out of a white studio background and crops to it', () {
    final rgba = draw(200, 100, [250, 250, 250], [200, 30, 30], carShape);
    final cut = removeBackground(rgba, 200, 100);

    expect(cut, isNotNull);
    expect(cut!.width, inInclusiveRange(150, 165));
    expect(cut.height, inInclusiveRange(65, 75));
    // Miðja bílsins er heil og rauð, horn afmörkunarinnar gegnsætt.
    final center = ((cut.height ~/ 2) * cut.width + cut.width ~/ 2) * 4;
    expect(cut.rgba[center + 3], 255);
    expect(cut.rgba[center], greaterThan(150));
    expect(cut.rgba[3], 0);
  });

  test('handles a soft grey gradient behind the car', () {
    final rgba = Uint8List(200 * 100 * 4);
    for (var y = 0; y < 100; y++) {
      for (var x = 0; x < 200; x++) {
        final i = (y * 200 + x) * 4;
        final grey = 255 - y ~/ 3; // ljós grár halli
        final car = carShape(x, y);
        rgba
          ..[i] = car ? 20 : grey
          ..[i + 1] = car ? 60 : grey
          ..[i + 2] = car ? 160 : grey
          ..[i + 3] = 255;
      }
    }
    expect(removeBackground(rgba, 200, 100), isNotNull);
  });

  test('keeps posters and framed pictures as cards', () {
    // Mynd í ramma: ramminn hverfur en restin er fylltur kassi.
    final rgba = draw(
      200,
      100,
      [255, 255, 255],
      [90, 120, 140],
      (x, y) => x > 8 && x < 192 && y > 8 && y < 92,
    );
    expect(removeBackground(rgba, 200, 100), isNull);
  });

  test('gives up when the car is the same colour as the background', () {
    final rgba = draw(200, 100, [250, 250, 250], [246, 246, 246], carShape);
    expect(removeBackground(rgba, 200, 100), isNull);
  });
}
