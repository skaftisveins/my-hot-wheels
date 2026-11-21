import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../models/car.dart';
import '../services/device_tilt.dart';
import '../services/photo_store.dart';
import '../widgets/own_photo.dart';
import '../widgets/showroom_photo.dart';
import 'car_form_screen.dart';

/// Opnar sýningarhaminn: sviðið birtist og myndin flýgur úr bílskúrnum á það.
Route<void> showroomRoute({required List<String> carIds, required int initialIndex}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 480),
    reverseTransitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, _, _) => CarDetailScreen(carIds: carIds, initialIndex: initialIndex),
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: child,
    ),
  );
}

/// Sýningarhamur: einn bíll í einu á upplýstu sviði.
///
/// * Strjúka til hliðar til að fletta (líka örvatakkar á lyklaborði).
/// * Ýta á myndina til að fela allt nema bílinn.
/// * Tvísmella eða klípa til að súma inn.
/// * Strjúka upp eða ýta á „Nánar“ til að sjá allar upplýsingar.
class CarDetailScreen extends StatefulWidget {
  const CarDetailScreen({super.key, required this.carIds, required this.initialIndex});

  final List<String> carIds;
  final int initialIndex;

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> with SingleTickerProviderStateMixin {
  static const _slideDuration = Duration(milliseconds: 4800);

  /// Halli símans (-1 til 1), mýktur. Hliðrar bílnum og stýrir glampanum.
  final _parallax = ValueNotifier<double>(0);
  bool _sensor = false;
  void Function()? _stopSensor;

  /// Án hallaskynjara rennur glampinn einu sinni yfir bílinn þegar hann birtist.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
    value: 1,
  );
  late final Animation<double> _sweepPosition = _sweep.drive(
    Tween<double>(begin: -1.4, end: 1.4).chain(CurveTween(curve: Curves.easeInOutCubic)),
  );

  ValueListenable<double> get _sheen => _sensor ? _parallax : _sweepPosition;

  @override
  void initState() {
    super.initState();
    if (DeviceTilt.available && !DeviceTilt.needsPermission) _listenToTilt();
    Future.delayed(const Duration(milliseconds: 500), _sweepLight);
  }

  void _sweepLight() {
    if (!mounted || _sensor || MediaQuery.disableAnimationsOf(context)) return;
    _sweep.forward(from: 0);
  }

  void _listenToTilt() {
    _stopSensor?.call();
    _stopSensor = DeviceTilt.listen((degrees) {
      if (!_sensor) setState(() => _sensor = true);
      final target = (degrees / 28).clamp(-1.0, 1.0);
      _parallax.value += (target - _parallax.value) * 0.25;
    });
  }

  Future<void> _enableTilt() async {
    // Á iPhone verður að biðja um leyfi beint úr smellinum.
    final granted = await DeviceTilt.requestPermission();
    if (!mounted) return;
    if (granted) {
      _listenToTilt();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hallaðu símanum til að færa ljósið yfir bílinn')),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Fékk ekki leyfi til að lesa halla símans')));
    }
  }

  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  int _direction = 1;
  bool _chrome = true;
  Timer? _slideshow;
  final _stage = <String, StageColors>{};

  @override
  void dispose() {
    _stopSensor?.call();
    _sweep.dispose();
    _parallax.dispose();
    _slideshow?.cancel();
    _pages.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  bool get _playing => _slideshow != null;

  void _setChrome(bool visible) {
    if (_chrome == visible) return;
    setState(() => _chrome = visible);
    SystemChrome.setEnabledSystemUIMode(
      visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void _goTo(int index, int count) {
    if (index < 0 || index >= count) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _togglePlay(int count) {
    if (_playing) {
      _stopSlideshow();
      return;
    }
    if (_index >= count - 1) _pages.jumpToPage(0);
    _setChrome(false);
    setState(() {
      _slideshow = Timer.periodic(_slideDuration, (_) {
        if (_index >= count - 1) {
          _stopSlideshow();
        } else {
          _goTo(_index + 1, count);
        }
      });
    });
  }

  void _stopSlideshow({bool showChrome = true}) {
    if (_slideshow == null) return;
    _slideshow!.cancel();
    setState(() => _slideshow = null);
    if (showChrome) _setChrome(true);
  }

  /// Sviðslitirnir fylgja myndinni, svo þeir breytast ef ný mynd er tekin.
  void _resolveStage(Car car) {
    final url = car.displayImage;
    if (url == null || _stage.containsKey(url)) return;
    _stage[url] = StageColors.fallback;
    stageColorsFor(url).then((colors) {
      if (mounted) setState(() => _stage[url] = colors);
    });
  }

  StageColors _stageFor(Car car) => _stage[car.displayImage] ?? StageColors.fallback;

  StageColors _stageAt(List<Car> cars, double page) {
    StageColors at(int i) => _stageFor(cars[i.clamp(0, cars.length - 1)]);
    final lower = page.floor();
    return StageColors.lerp(at(lower), at(lower + 1), page - lower);
  }

  Future<void> _takePhoto(Car car) async {
    _stopSlideshow();
    final store = AppScope.readStore(context);
    final id = await takeOwnPhoto(context);
    if (id == null) return;
    final previous = car.ownPhoto;
    await store.setOwnPhoto(car.id, id);
    if (previous != null) await PhotoStore.instance.delete(previous);
  }

  Future<void> _delete(Car car) async {
    _stopSlideshow();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eyða bíl?'),
        content: Text('Viltu fjarlægja ${car.name} úr safninu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hætta við'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eyða')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final store = AppScope.readStore(context);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    await store.remove(car.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('${car.name} var eytt'),
        action: SnackBarAction(label: 'Afturkalla', onPressed: () => store.restore(car)),
      ),
    );
  }

  void _openDetails(Car car, ThemeData theme) {
    _stopSlideshow();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      builder: (_) => Theme(
        data: theme,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.92,
          builder: (context, scroll) => _DetailsSheet(carId: car.id, controller: scroll),
        ),
      ),
    );
  }

  KeyEventResult _onKey(KeyEvent event, int count) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      _goTo(_index + 1, count);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _goTo(_index - 1, count);
    } else if (key == LogicalKeyboardKey.space) {
      _togglePlay(count);
    } else if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.storeOf(context);
    final cars = widget.carIds.map(store.byId).whereType<Car>().toList();
    if (cars.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Bíllinn fannst ekki.')),
      );
    }
    final index = _index.clamp(0, cars.length - 1);
    final car = cars[index];
    for (final i in [index - 1, index, index + 1]) {
      if (i >= 0 && i < cars.length) _resolveStage(cars[i]);
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final fade = reduceMotion ? Duration.zero : const Duration(milliseconds: 260);
    final current = _stageFor(car);
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: current.glow, brightness: Brightness.dark),
    );

    return Theme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, event) => _onKey(event, cars.length),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // Sviðið: ljómi í lit bílsins sem breytist mjúklega þegar flett er.
                AnimatedBuilder(
                  animation: _pages,
                  builder: (context, _) {
                    final page = _pages.hasClients && _pages.position.hasContentDimensions
                        ? _pages.page ?? index.toDouble()
                        : index.toDouble();
                    return _StageBackground(colors: _stageAt(cars, page));
                  },
                ),
                // Líka hægt að draga með mús (í tölvu), ekki bara strjúka með fingri.
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: cars.length,
                    physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
                    onPageChanged: (i) {
                      setState(() {
                        _direction = i >= _index ? 1 : -1;
                        _index = i;
                      });
                      _sweepLight();
                    },
                    itemBuilder: (context, i) => _StagePage(
                      car: cars[i],
                      index: i,
                      controller: _pages,
                      chromeVisible: _chrome,
                      kenBurns: _playing && i == index,
                      parallax: _sensor ? _parallax : null,
                      sheen: _sheen,
                      onTap: () {
                        if (_playing) {
                          _stopSlideshow();
                        } else {
                          _setChrome(!_chrome);
                        }
                      },
                      onDoubleTap: () {
                        _stopSlideshow(showChrome: false);
                        Navigator.of(context).push(
                          PageRouteBuilder<void>(
                            opaque: false,
                            transitionDuration: const Duration(milliseconds: 320),
                            reverseTransitionDuration: const Duration(milliseconds: 260),
                            pageBuilder: (_, _, _) => _ZoomView(car: cars[i]),
                            transitionsBuilder: (_, animation, _, child) =>
                                FadeTransition(opacity: animation, child: child),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Efsta röðin
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_chrome,
                    child: AnimatedOpacity(
                      opacity: _chrome ? 1 : 0,
                      duration: fade,
                      child: AnimatedSlide(
                        offset: _chrome ? Offset.zero : const Offset(0, -0.4),
                        duration: fade,
                        curve: Curves.easeOutCubic,
                        child: _TopBar(
                          onEnableTilt: DeviceTilt.needsPermission && !_sensor ? _enableTilt : null,
                          counter: cars.length > 1 ? '${index + 1} af ${cars.length}' : null,
                          favorite: car.favorite,
                          playing: _playing,
                          canPlay: cars.length > 1,
                          onBack: () => Navigator.of(context).maybePop(),
                          onFavorite: () => store.toggleFavorite(car.id),
                          onPlay: () => _togglePlay(cars.length),
                          onEdit: () {
                            _stopSlideshow();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CarFormScreen(car: car, isNew: false),
                              ),
                            );
                          },
                          onDelete: () => _delete(car),
                          onTakePhoto: () => _takePhoto(car),
                          onUseWikiPhoto: car.ownPhoto != null && car.imageUrl != null
                              ? () => store.setOwnPhoto(car.id, null)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                // Nafn og helstu upplýsingar neðst
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !_chrome,
                    child: AnimatedOpacity(
                      opacity: _chrome ? 1 : 0,
                      duration: fade,
                      child: AnimatedSlide(
                        offset: _chrome ? Offset.zero : const Offset(0, 0.25),
                        duration: fade,
                        curve: Curves.easeOutCubic,
                        child: GestureDetector(
                          onVerticalDragEnd: (d) {
                            if ((d.primaryVelocity ?? 0) < -250) _openDetails(car, theme);
                          },
                          child: _Caption(
                            car: car,
                            direction: _direction,
                            accent: current.glow,
                            reduceMotion: reduceMotion,
                            onDetails: () => _openDetails(car, theme),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageBackground extends StatelessWidget {
  const _StageBackground({required this.colors});

  final StageColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.05,
          colors: [colors.glow, Color.lerp(colors.glow, colors.base, 0.75)!, colors.base],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: DecoratedBox(
        // Gljáandi gólf: aðeins dekkra neðst svo nafnið sé alltaf læsilegt.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.55, 1],
            colors: [Colors.transparent, colors.base.withValues(alpha: 0.9)],
          ),
        ),
      ),
    );
  }
}

class _StagePage extends StatelessWidget {
  const _StagePage({
    required this.car,
    required this.index,
    required this.controller,
    required this.chromeVisible,
    required this.kenBurns,
    required this.onTap,
    required this.onDoubleTap,
    required this.parallax,
    required this.sheen,
  });

  final Car car;
  final int index;
  final PageController controller;
  final bool chromeVisible;
  final bool kenBurns;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueListenable<double>? parallax;
  final ValueListenable<double> sheen;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final photo = Hero(
      tag: 'car-${car.id}',
      // Á fluginu milli skjáa sést bara kortið sjálft, án spegilmyndar.
      flightShuttleBuilder: (_, _, _, _, _) =>
          ShowroomPhoto(url: car.displayImage, reflection: false),
      child: ShowroomPhoto(
        url: car.displayImage,
        kenBurns: kenBurns,
        parallax: parallax,
        sheen: sheen,
      ),
    );

    // Þegar flett er hallar kortið aðeins í þrívídd og minnkar.
    final stage = AnimatedBuilder(
      animation: controller,
      child: photo,
      builder: (context, child) {
        if (reduceMotion) return child!;
        var delta = 0.0;
        final position = controller.hasClients ? controller.position : null;
        if (position != null && position.hasContentDimensions) {
          delta = ((controller.page ?? index.toDouble()) - index).clamp(-1.0, 1.0);
        }
        final t = delta.abs();
        return Opacity(
          opacity: 1 - t * 0.55,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0011)
              ..rotateY(delta * 0.55)
              ..scaleByDouble(1 - t * 0.14, 1 - t * 0.14, 1, 1),
            child: child,
          ),
        );
      },
    );

    // Bara snertingar hér (ekki klíp/drátt) svo það trufli aldrei flettingu.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: car.displayImage == null ? null : onDoubleTap,
      child: AnimatedPadding(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        // Þegar valmyndirnar eru faldar fær bíllinn allt plássið.
        padding: chromeVisible
            ? EdgeInsets.fromLTRB(20, padding.top + 72, 20, padding.bottom + 190)
            : EdgeInsets.fromLTRB(12, padding.top + 24, 12, padding.bottom + 24),
        child: stage,
      ),
    );
  }
}

/// Myndin ein á svörtum fleti: klípa til að súma, draga til að skoða,
/// tvísmella til að súma að punkti, ýta einu sinni til að loka.
class _ZoomView extends StatefulWidget {
  const _ZoomView({required this.car});

  final Car car;

  @override
  State<_ZoomView> createState() => _ZoomViewState();
}

class _ZoomViewState extends State<_ZoomView> with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  Offset _tapAt = Offset.zero;

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    const scale = 2.6;
    final end = zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(-_tapAt.dx * (scale - 1), -_tapAt.dy * (scale - 1), 0, 1)
            ..scaleByDouble(scale, scale, 1, 1));
    final tween = Matrix4Tween(begin: _transform.value, end: end);
    final curve = CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic);
    void tick() => _transform.value = tween.evaluate(curve);
    _animation
      ..addListener(tick)
      ..forward(from: 0).whenComplete(() => _animation.removeListener(tick));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            onDoubleTapDown: (d) => _tapAt = d.localPosition,
            onDoubleTap: _toggleZoom,
            child: InteractiveViewer(
              transformationController: _transform,
              maxScale: 5,
              child: SizedBox.expand(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Hero(
                    tag: 'car-${widget.car.id}',
                    child: ShowroomPhoto(url: widget.car.displayImage, reflection: false),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Loka',
                color: Colors.white,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.counter,
    required this.favorite,
    required this.playing,
    required this.canPlay,
    required this.onBack,
    required this.onFavorite,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
    required this.onTakePhoto,
    this.onUseWikiPhoto,
    this.onEnableTilt,
  });

  final String? counter;
  final bool favorite;
  final bool playing;
  final bool canPlay;
  final VoidCallback onBack;
  final VoidCallback onFavorite;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTakePhoto;
  final VoidCallback? onUseWikiPhoto;

  /// Sýnt á iPhone þar sem biðja þarf um leyfi til að lesa halla símans.
  final VoidCallback? onEnableTilt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onStage = Colors.white;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: IconTheme(
          data: const IconThemeData(color: onStage),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Til baka',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: counter == null
                    ? const SizedBox.shrink()
                    : Text(
                        counter!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: onStage.withValues(alpha: 0.7),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
              ),
              if (onEnableTilt != null)
                IconButton(
                  tooltip: 'Færa ljósið með því að halla símanum',
                  onPressed: onEnableTilt,
                  icon: const Icon(Icons.screen_rotation_alt_rounded),
                ),
              if (canPlay)
                IconButton(
                  tooltip: playing ? 'Stöðva sýningu' : 'Spila sýningu',
                  onPressed: onPlay,
                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
              IconButton(
                tooltip: favorite ? 'Taka úr uppáhalds' : 'Setja í uppáhalds',
                onPressed: onFavorite,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                    child: child,
                  ),
                  child: Icon(
                    favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    key: ValueKey(favorite),
                    color: favorite ? const Color(0xFFFFC94A) : onStage,
                  ),
                ),
              ),
              PopupMenuButton<void>(
                tooltip: 'Meira',
                icon: const Icon(Icons.more_vert_rounded, color: onStage),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: onTakePhoto,
                    child: const ListTile(
                      leading: Icon(Icons.photo_camera_outlined),
                      title: Text('Taka mynd af bílnum'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (onUseWikiPhoto != null)
                    PopupMenuItem(
                      onTap: onUseWikiPhoto,
                      child: const ListTile(
                        leading: Icon(Icons.public_rounded),
                        title: Text('Nota wiki-myndina'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  PopupMenuItem(
                    onTap: onEdit,
                    child: const ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Breyta upplýsingum'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    onTap: onDelete,
                    child: const ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Eyða bíl'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({
    required this.car,
    required this.direction,
    required this.accent,
    required this.reduceMotion,
    required this.onDetails,
  });

  final Car car;
  final int direction;
  final Color accent;
  final bool reduceMotion;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentText = Color.lerp(accent, Colors.white, 0.55)!;
    final secondary = [car.color, car.series].whereType<String>().join(', ');

    final caption = Column(
      key: ValueKey(car.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (car.year != null)
          Text(
            '${car.year}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: accentText,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        Text(
          car.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: -0.8,
          ),
        ),
        if (secondary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
      ],
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) =>
                    Stack(alignment: Alignment.bottomLeft, children: [...previous, ?current]),
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey(car.id);
                  final from = Offset((incoming ? 0.18 : -0.18) * direction, 0);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: from, end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: caption,
              ),
            ),
            TextButton.icon(
              onPressed: onDetails,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              label: const Text('Nánar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Allar upplýsingar um bílinn, í blaði sem dregið er upp.
class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({required this.carId, required this.controller});

  final String carId;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.storeOf(context);
    final car = store.byId(carId);
    if (car == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final wikiUrl = car.wikiUrl;
    final details = <(String, String?)>[
      ('Árgerð', car.year?.toString()),
      ('Sería', [car.series, car.seriesNumber].whereType<String>().join(' ')),
      ('Safnnúmer', car.collectorNumber),
      ('Litur', car.color),
      ('Skreyting', car.tampo),
      ('Felgur', car.wheelType),
      ('Botn', car.baseColor),
      ('Rúður', car.windowColor),
      ('Innrétting', car.interiorColor),
      ('Vörunúmer', car.toyNumber),
      ('Framleitt í', car.country),
      ('Hönnuður', car.designer),
    ].where((d) => d.$2 != null && d.$2!.isNotEmpty).toList();

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        Text(car.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              avatar: Icon(
                car.condition == CarCondition.carded
                    ? Icons.inventory_2_outlined
                    : Icons.toys_outlined,
              ),
              label: Text(car.condition.label),
            ),
            _QuantityStepper(
              quantity: car.quantity,
              onChanged: (q) => store.setQuantity(car.id, q),
            ),
          ],
        ),
        if (car.notes != null && car.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(car.notes!, style: theme.textTheme.bodyLarge),
        ],
        if (details.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final (label, value) in details)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                  Expanded(child: Text(value!, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
        const SizedBox(height: 16),
        Text(
          'Skráður ${MaterialLocalizations.of(context).formatMediumDate(car.addedAt)}',
          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        if (wikiUrl != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => launchUrl(wikiUrl, mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Skoða á Hot Wheels Wiki'),
            ),
          ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Fækka eintökum',
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Text(quantity == 1 ? '1 eintak' : '$quantity eintök', style: theme.textTheme.labelLarge),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Fjölga eintökum',
            onPressed: () => onChanged(quantity + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
