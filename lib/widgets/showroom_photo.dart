import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

/// Myndaþjónn Hot Wheels Wiki skilar myndum í þeirri breidd sem beðið er um
/// (`.../scale-to-width-down/500`). Í sýningarham biðjum við um stærri mynd.
String? hiResUrl(String? url, {int width = 1280}) =>
    url?.replaceFirst(RegExp(r'scale-to-width-down/\d+'), 'scale-to-width-down/$width');

final _aspectCache = <String, double>{};
final _stageCache = <String, StageColors>{};

/// Hlutfall breiddar og hæðar myndar (úr skyndiminni ef hún hefur sést áður).
Future<double?> imageAspect(String url) {
  final cached = _aspectCache[url];
  if (cached != null) return Future.value(cached);

  final completer = Completer<double?>();
  final stream = CachedNetworkImageProvider(url).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      final aspect = info.image.width / info.image.height;
      _aspectCache[url] = aspect;
      if (!completer.isCompleted) completer.complete(aspect);
      stream.removeListener(listener);
    },
    onError: (_, _) {
      if (!completer.isCompleted) completer.complete(null);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

/// Litirnir á „sviðinu“ sem bíllinn stendur á: ljómi í lit bílsins og dökkur grunnur.
@immutable
class StageColors {
  const StageColors(this.glow, this.base);

  /// Hlutlaus blár þegar engin mynd er til.
  static const fallback = StageColors(Color(0xFF35507A), Color(0xFF0A1220));

  /// Grafítgrátt svið fyrir litlausa bíla (svarta, hvíta, silfraða).
  static const neutral = StageColors(Color(0xFF4A5260), Color(0xFF0B0D11));

  factory StageColors.fromPaint(Color paint) {
    final hsl = HSLColor.fromColor(paint);
    return StageColors(
      hsl.withSaturation(math.min(hsl.saturation, 0.7)).withLightness(0.38).toColor(),
      hsl.withSaturation(math.min(hsl.saturation, 0.45)).withLightness(0.065).toColor(),
    );
  }

  final Color glow;
  final Color base;

  static StageColors lerp(StageColors a, StageColors b, double t) =>
      StageColors(Color.lerp(a.glow, b.glow, t)!, Color.lerp(a.base, b.base, t)!);

  @override
  bool operator ==(Object other) =>
      other is StageColors && other.glow == glow && other.base == base;

  @override
  int get hashCode => Object.hash(glow, base);
}

/// Finnur lit bílsins í myndinni og býr til sviðslitina út frá honum.
Future<StageColors> stageColorsFor(String? url) async {
  if (url == null || url.isEmpty) return StageColors.fallback;
  final cached = _stageCache[url];
  if (cached != null) return cached;
  try {
    final image = await _decode(CachedNetworkImageProvider(url));
    final bytes = await image.toByteData();
    if (bytes == null) return StageColors.fallback;
    final paint = dominantPaint(bytes.buffer.asUint8List(), image.width, image.height);
    return _stageCache[url] = paint == null ? StageColors.neutral : StageColors.fromPaint(paint);
  } catch (_) {
    return StageColors.fallback;
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

/// Litur lakksins á bílnum, fundinn úr RGBA-punktum myndarinnar.
///
/// Gráir, hvítir og svartir punktar (bakgrunnur, dekk, gler) eru hunsaðir og
/// algengasti litatónninn valinn, vigtaður eftir því hve sterkur liturinn er.
/// Skilar `null` ef bíllinn er nánast litlaus (t.d. svartur, hvítur eða silfur).
Color? dominantPaint(Uint8List rgba, int width, int height) {
  const bins = 36;
  final weight = List<double>.filled(bins, 0);
  final sumR = List<double>.filled(bins, 0);
  final sumG = List<double>.filled(bins, 0);
  final sumB = List<double>.filled(bins, 0);
  final pixels = width * height;
  final step = math.max(1, pixels ~/ 12000);
  var sampled = 0;

  for (var p = 0; p < pixels; p += step) {
    final i = p * 4;
    if (rgba[i + 3] < 128) continue;
    sampled++;
    final r = rgba[i] / 255, g = rgba[i + 1] / 255, b = rgba[i + 2] / 255;
    final hsv = HSVColor.fromColor(Color.from(alpha: 1, red: r, green: g, blue: b));
    if (hsv.saturation < 0.3 || hsv.value < 0.2) continue;
    final w = hsv.saturation * hsv.value;
    final bin = (hsv.hue / 360 * bins).floor() % bins;
    weight[bin] += w;
    sumR[bin] += r * w;
    sumG[bin] += g * w;
    sumB[bin] += b * w;
  }
  if (sampled == 0) return null;

  // Nágrannatónar teljast saman svo t.d. rauður og vínrauður keppi ekki.
  var best = 0;
  var bestWeight = 0.0;
  for (var bin = 0; bin < bins; bin++) {
    final w = weight[bin] + 0.5 * (weight[(bin + 1) % bins] + weight[(bin - 1 + bins) % bins]);
    if (w > bestWeight) {
      bestWeight = w;
      best = bin;
    }
  }
  // Of lítið af lit: líklega svartur, hvítur eða silfurlitur bíll.
  if (weight[best] / sampled < 0.015) return null;
  final w = weight[best];
  return Color.from(alpha: 1, red: sumR[best] / w, green: sumG[best] / w, blue: sumB[best] / w);
}

/// Myndin af bílnum sem „gljáandi safnkort“: ávöl horn í réttu hlutfalli,
/// skörp mynd sem birtist ofan á minni myndinni, og spegilmynd á glergólfi.
class ShowroomPhoto extends StatefulWidget {
  const ShowroomPhoto({
    super.key,
    required this.url,
    this.reflection = true,
    this.kenBurns = false,
  });

  final String? url;
  final bool reflection;

  /// Hægur aðdráttur á myndina (notað í myndasýningu).
  final bool kenBurns;

  @override
  State<ShowroomPhoto> createState() => _ShowroomPhotoState();
}

class _ShowroomPhotoState extends State<ShowroomPhoto> {
  double? _aspect;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ShowroomPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolve();
  }

  Future<void> _resolve() async {
    final url = widget.url;
    if (url == null || url.isEmpty) return;
    _aspect = _aspectCache[url];
    if (_aspect != null) return;
    final aspect = await imageAspect(url);
    if (mounted && url == widget.url) setState(() => _aspect = aspect);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (url == null || url.isEmpty) {
          return Center(
            child: Icon(
              Icons.directions_car_filled_rounded,
              size: math.min(constraints.maxWidth, constraints.maxHeight) * 0.4,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          );
        }
        final aspect = _aspect;
        if (aspect == null) return const SizedBox.expand();

        // Stærsta kort í réttu hlutfalli sem kemst fyrir, og pláss undir fyrir spegilmynd.
        const reflectionShare = 0.28;
        final availableHeight = widget.reflection
            ? constraints.maxHeight / (1 + reflectionShare)
            : constraints.maxHeight;
        var width = constraints.maxWidth;
        var height = width / aspect;
        if (height > availableHeight) {
          height = availableHeight;
          width = height * aspect;
        }
        final radius = BorderRadius.circular(math.min(22, width * 0.05));

        Widget photo = _Layers(url: url, kenBurns: widget.kenBurns);
        photo = ClipRRect(borderRadius: radius, child: photo);

        final card = SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 24)),
              ],
            ),
            child: photo,
          ),
        );

        if (!widget.reflection) return Center(child: card);

        final reflectionHeight = height * reflectionShare;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              card,
              const SizedBox(height: 6),
              SizedBox(
                width: width,
                height: reflectionHeight,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: height,
                    minHeight: height,
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, reflectionShare * 0.9],
                        colors: [Colors.white.withValues(alpha: 0.22), Colors.transparent],
                      ).createShader(rect),
                      child: Transform.flip(
                        flipY: true,
                        child: ClipRRect(
                          borderRadius: radius,
                          child: _Layers(url: url),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Minni myndin strax (úr skyndiminni) og skarpa myndin sem birtist yfir henni.
class _Layers extends StatelessWidget {
  const _Layers({required this.url, this.kenBurns = false});

  final String url;
  final bool kenBurns;

  @override
  Widget build(BuildContext context) {
    final hiRes = hiResUrl(url)!;
    Widget image = Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, fadeInDuration: Duration.zero),
        if (hiRes != url)
          CachedNetworkImage(
            imageUrl: hiRes,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 400),
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
      ],
    );
    if (kenBurns && !MediaQuery.disableAnimationsOf(context)) {
      image = TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 1.06),
        duration: const Duration(seconds: 5),
        curve: Curves.easeInOutSine,
        builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
        child: image,
      );
    }
    return image;
  }
}
