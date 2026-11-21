import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hot_wheels_safn/widgets/showroom_photo.dart';
import 'package:material_ui/material_ui.dart';

/// Mynd þar sem [share] af punktunum eru [paint] og restin [background].
Uint8List picture(Color paint, Color background, double share, {int size = 100}) {
  final bytes = Uint8List(size * size * 4);
  for (var p = 0; p < size * size; p++) {
    final c = p < size * size * share ? paint : background;
    bytes
      ..[p * 4] = (c.r * 255).round()
      ..[p * 4 + 1] = (c.g * 255).round()
      ..[p * 4 + 2] = (c.b * 255).round()
      ..[p * 4 + 3] = 255;
  }
  return bytes;
}

void main() {
  test('finds the paint colour on a white studio background', () {
    final paint = dominantPaint(
      picture(const Color(0xFFD32F2F), const Color(0xFFF5F5F5), 0.2),
      100,
      100,
    );
    expect(paint, isNotNull);
    final hue = HSVColor.fromColor(paint!).hue;
    expect(hue < 15 || hue > 345, isTrue, reason: 'expected red, got hue $hue');
  });

  test('a black car with a thin red stripe still gets red, not something random', () {
    final paint = dominantPaint(
      picture(const Color(0xFFC62828), const Color(0xFF111111), 0.05),
      100,
      100,
    );
    expect(HSVColor.fromColor(paint!).hue, anyOf(lessThan(15), greaterThan(345)));
  });

  test('colourless cars (black, white, silver) give no paint colour', () {
    expect(
      dominantPaint(picture(const Color(0xFF9E9E9E), const Color(0xFFFFFFFF), 0.5), 100, 100),
      isNull,
    );
    expect(
      dominantPaint(picture(const Color(0xFF101010), const Color(0xFFEEEEEE), 0.5), 100, 100),
      isNull,
    );
  });

  test('hiResUrl asks the wiki image server for a larger image', () {
    expect(
      hiResUrl(
        'https://static.wikia.nocookie.net/a/b.jpg/revision/latest/scale-to-width-down/500?cb=1',
      ),
      'https://static.wikia.nocookie.net/a/b.jpg/revision/latest/scale-to-width-down/1280?cb=1',
    );
    expect(hiResUrl('https://example.com/car.png'), 'https://example.com/car.png');
    expect(hiResUrl(null), isNull);
  });
}
