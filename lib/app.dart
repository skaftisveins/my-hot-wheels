import 'package:material_ui/material_ui.dart';

import 'data/collection_store.dart';
import 'screens/collection_screen.dart';
import 'services/hot_wheels_wiki_api.dart';

/// Gerir safnið og wiki-tenginguna aðgengileg öllum skjám.
class AppScope extends InheritedNotifier<CollectionStore> {
  const AppScope({
    super.key,
    required CollectionStore store,
    required this.api,
    required super.child,
  }) : super(notifier: store);

  final HotWheelsWikiApi api;

  static CollectionStore storeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Nær í safnið án þess að endurteikna þegar það breytist (t.d. í onPressed).
  static CollectionStore readStore(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static HotWheelsWikiApi apiOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.api;
}

class BilasafnApp extends StatelessWidget {
  const BilasafnApp({super.key, required this.store, required this.api});

  final CollectionStore store;
  final HotWheelsWikiApi api;

  static const _flameOrange = Color(0xFFFF6A00);

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _flameOrange,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    return ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: store,
      api: api,
      child: MaterialApp(
        title: 'Bílasafnið',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        locale: const Locale('is'),
        supportedLocales: const [Locale('is'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const CollectionScreen(),
      ),
    );
  }
}
