import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

/// Bíll sem hefur verið klipptur út úr mynd (gegnsær bakgrunnur).
class Cutout {
  const Cutout(this.image);

  final ui.Image image;

  double get aspect => image.width / image.height;
}

/// Pixlar útklippts bíls (RGBA, forlitað með gegnsæi), skornir að bílnum.
class CutoutPixels {
  const CutoutPixels(this.rgba, this.width, this.height, this.removedShare);

  final Uint8List rgba;
  final int width;
  final int height;

  /// Hlutfall myndarinnar sem var bakgrunnur.
  final double removedShare;
}

final _cache = <String, Future<Cutout?>>{};

/// Klippir bílinn út úr myndinni á [url]. Skilar `null` ef myndin hentar ekki
/// (t.d. teikning, plakat eða hvítur bíll á hvítum bakgrunni) og þá er
/// myndin sýnd sem kort í staðinn.
Future<Cutout?> cutoutFor(String url) => _cache.putIfAbsent(url, () => _make(url));

/// Skilar útklippunni strax ef hún er tilbúin (t.d. á fluginu milli skjáa).
Cutout? cachedCutout(String url) => _ready[url];
final _ready = <String, Cutout>{};

Future<Cutout?> _make(String url) async {
  try {
    final source = await _decode(CachedNetworkImageProvider(url));
    const maxWidth = 900;
    final scale = math.min(1.0, maxWidth / source.width);
    final w = (source.width * scale).round();
    final h = (source.height * scale).round();

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final scaled = await recorder.endRecording().toImage(w, h);
    final bytes = await scaled.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (bytes == null) return null;

    final pixels = removeBackground(bytes.buffer.asUint8List(), w, h);
    if (pixels == null) return null;

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels.rgba,
      pixels.width,
      pixels.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final cutout = Cutout(await completer.future);
    _ready[url] = cutout;
    return cutout;
  } catch (_) {
    return null;
  }
}

Future<ui.Image> _decode(ImageProvider provider) {
  final completer = Completer<ui.Image>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image.clone());
      stream.removeListener(listener);
    },
    onError: (error, stack) {
      if (!completer.isCompleted) completer.completeError(error, stack);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

/// Fjarlægir einlitan eða jafnan bakgrunn (stúdíómyndir) með því að fylla
/// frá jöðrum myndarinnar inn á við. Punktur telst bakgrunnur ef hann er
/// líkur jaðarpunktinum sem fyllingin byrjaði frá og nágranna sínum.
///
/// Skilar `null` ef niðurstaðan lítur ekki út eins og stakur bíll.
CutoutPixels? removeBackground(Uint8List rgba, int w, int h) {
  const seedTolerance = 34 * 3;
  const stepTolerance = 14 * 3;
  final n = w * h;
  final background = Uint8List(n);
  final seed = Int32List(n);
  final queue = Int32List(n);
  var head = 0, tail = 0;

  void push(int i, int s) {
    background[i] = 1;
    seed[i] = s;
    queue[tail++] = i;
  }

  for (var x = 0; x < w; x++) {
    for (final i in [x, (h - 1) * w + x]) {
      if (background[i] == 0) push(i, i);
    }
  }
  for (var y = 0; y < h; y++) {
    for (final i in [y * w, y * w + w - 1]) {
      if (background[i] == 0) push(i, i);
    }
  }

  int diff(int a, int b) =>
      (rgba[a * 4] - rgba[b * 4]).abs() +
      (rgba[a * 4 + 1] - rgba[b * 4 + 1]).abs() +
      (rgba[a * 4 + 2] - rgba[b * 4 + 2]).abs();

  while (head < tail) {
    final i = queue[head++];
    final s = seed[i];
    final x = i % w;
    void visit(int j) {
      if (background[j] == 0 && diff(j, s) < seedTolerance && diff(j, i) < stepTolerance) {
        push(j, s);
      }
    }

    if (x > 0) visit(i - 1);
    if (x < w - 1) visit(i + 1);
    if (i >= w) visit(i - w);
    if (i < n - w) visit(i + w);
  }

  // Afmörkun bílsins
  var minX = w, minY = h, maxX = -1, maxY = -1, kept = 0;
  for (var i = 0; i < n; i++) {
    if (background[i] == 1) continue;
    kept++;
    final x = i % w, y = i ~/ w;
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
  if (kept == 0) return null;
  final removed = 1 - kept / n;
  final boxW = maxX - minX + 1, boxH = maxY - minY + 1;
  final fill = kept / (boxW * boxH);

  // Of lítið fjarlægt = flókinn bakgrunnur eða rammi; of mikið = bíllinn
  // sjálfur fór með (t.d. hvítur bíll á hvítu). Fylltur kassi = plakat/kort.
  if (removed < 0.2 || removed > 0.72 || fill > 0.9 || boxW < w * 0.3) return null;

  // Mjúkar brúnir: minnka bílinn um einn punkt (engin ljós rönd) og mýkja.
  final alpha = Uint8List(n);
  for (var i = 0; i < n; i++) {
    if (background[i] == 1) continue;
    final x = i % w;
    final edge =
        (x > 0 && background[i - 1] == 1) ||
        (x < w - 1 && background[i + 1] == 1) ||
        (i >= w && background[i - w] == 1) ||
        (i < n - w && background[i + w] == 1);
    alpha[i] = edge ? 0 : 255;
  }

  final out = Uint8List(boxW * boxH * 4);
  for (var y = 0; y < boxH; y++) {
    for (var x = 0; x < boxW; x++) {
      final sx = x + minX, sy = y + minY;
      var sum = 0, count = 0;
      for (var dy = -1; dy <= 1; dy++) {
        final yy = sy + dy;
        if (yy < 0 || yy >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final xx = sx + dx;
          if (xx < 0 || xx >= w) continue;
          sum += alpha[yy * w + xx];
          count++;
        }
      }
      final a = sum ~/ count;
      final si = (sy * w + sx) * 4;
      final o = (y * boxW + x) * 4;
      out[o] = rgba[si] * a ~/ 255;
      out[o + 1] = rgba[si + 1] * a ~/ 255;
      out[o + 2] = rgba[si + 2] * a ~/ 255;
      out[o + 3] = a;
    }
  }
  return CutoutPixels(out, boxW, boxH, removed);
}
