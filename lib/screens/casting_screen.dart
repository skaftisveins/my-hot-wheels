import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../models/car.dart';
import '../models/casting.dart';
import '../services/hot_wheels_wiki_api.dart';
import '../widgets/car_image.dart';
import 'car_form_screen.dart';

/// Annað skrefið í skráningu: upplýsingar um bílgerðina og listi yfir allar
/// útgáfur hennar, svo hægt sé að velja þá sem passar við bílinn.
class CastingScreen extends StatefulWidget {
  const CastingScreen({super.key, required this.title});

  final String title;

  @override
  State<CastingScreen> createState() => _CastingScreenState();
}

class _CastingScreenState extends State<CastingScreen> {
  Casting? _casting;
  String? _error;
  String _filter = '';
  int? _year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_error != null) setState(() => _error = null);
    try {
      final casting = await AppScope.apiOf(context).fetchCasting(widget.title);
      if (mounted) setState(() => _casting = casting);
    } on WikiApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  static Car carFrom(Casting casting, CastingVersion? version) => Car(
    id: '',
    addedAt: DateTime.now(),
    name: casting.displayName,
    castingTitle: casting.title,
    designer: casting.designer,
    year: version?.year,
    series: version?.series,
    seriesNumber: version?.seriesNumber,
    collectorNumber: version?.collectorNumber,
    color: version?.color,
    tampo: version?.tampo,
    wheelType: version?.wheelType,
    toyNumber: version?.toyNumber ?? casting.toyNumber,
    baseColor: version?.baseColor,
    windowColor: version?.windowColor,
    interiorColor: version?.interiorColor,
    country: version?.country,
    imageUrl: version?.photoUrl ?? casting.imageUrl,
  );

  void _choose(Casting casting, CastingVersion? version) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CarFormScreen(car: carFrom(casting, version), isNew: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final casting = _casting;
    return Scaffold(
      appBar: AppBar(title: Text(casting?.displayName ?? widget.title)),
      body: switch ((casting, _error)) {
        (_, final String error) => _ErrorView(message: error, onRetry: _load),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final Casting c, _) when !c.isCasting => _NotACar(
          title: c.title,
          onRegister: () => _choose(c, null),
        ),
        (final Casting c, _) => _buildCasting(context, c),
      },
    );
  }

  Widget _buildCasting(BuildContext context, Casting casting) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final owned = AppScope.storeOf(context).sameModel(casting.title, casting.displayName);

    // Nýjustu útgáfurnar fyrst, því þær eru líklegastar í dótakassanum.
    final all = [...casting.versions]..sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
    final years = all.map((v) => v.year).whereType<int>().toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final terms = _filter.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final versions = all
        .where((v) => _year == null || v.year == _year)
        .where((v) => terms.every(v.searchText.contains))
        .toList();

    final facts = <(IconData, String)>[
      if (casting.designer != null) (Icons.brush_outlined, 'Hönnuður: ${casting.designer}'),
      if (casting.yearsText != null)
        (Icons.calendar_month_outlined, 'Framleiddur: ${icelandicYears(casting.yearsText)}'),
      if (casting.series != null) (Icons.flag_outlined, 'Kom fyrst í: ${casting.series}'),
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CarImage(url: casting.imageUrl, iconSize: 80),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverList.list(
            children: [
              Text(
                casting.displayName,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final (icon, text) in facts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    spacing: 8,
                    children: [
                      Icon(icon, size: 18, color: colors.onSurfaceVariant),
                      Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
              if (owned.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card.filled(
                  color: colors.tertiaryContainer,
                  child: ListTile(
                    leading: Icon(Icons.garage_rounded, color: colors.onTertiaryContainer),
                    title: Text(
                      owned.length == 1
                          ? 'Þú átt nú þegar 1 svona bíl'
                          : 'Þú átt nú þegar ${owned.length} svona bíla',
                      style: TextStyle(color: colors.onTertiaryContainer),
                    ),
                    subtitle: Text(
                      owned.map((c) => [c.year, c.color].whereType<Object>().join(' ')).join(', '),
                      style: TextStyle(color: colors.onTertiaryContainer),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Hvaða útgáfu ertu með?', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Finndu bílinn sem er eins á litinn og með sömu skreytingu og felgur. '
                'Það eru ${casting.versions.length} útgáfur til.',
                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Sía, t.d. „red“ eða „2024“',
                  prefixIcon: Icon(Icons.filter_list_rounded),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ],
          ),
        ),
        if (years.length > 1)
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                spacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Öll ár'),
                    selected: _year == null,
                    onSelected: (_) => setState(() => _year = null),
                  ),
                  for (final year in years)
                    ChoiceChip(
                      label: Text('$year'),
                      selected: _year == year,
                      onSelected: (_) => setState(() => _year = _year == year ? null : year),
                    ),
                ],
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (versions.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                casting.versions.isEmpty
                    ? 'Engar útgáfur eru skráðar á wiki-síðunni.'
                    : 'Engin útgáfa passar við síuna.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          SliverList.separated(
            itemCount: versions.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 132),
            itemBuilder: (context, i) =>
                _VersionTile(version: versions[i], onTap: () => _choose(casting, versions[i])),
          ),
        SliverSafeArea(
          top: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: OutlinedButton.icon(
                onPressed: () => _choose(casting, null),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Finn ekki útgáfuna — skrá án hennar'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({required this.version, required this.onTap});

  final CastingVersion version;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = [
      version.year?.toString() ?? version.yearText,
      version.color,
    ].whereType<String>().join(' · ');
    final lines = [
      [version.series, version.seriesNumber].whereType<String>().join(' '),
      ?version.tampo,
      if (version.wheelType != null) 'Felgur: ${version.wheelType}',
    ].where((l) => l.isNotEmpty);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 104,
                height: 72,
                child: CarImage(url: version.photoUrl, fit: BoxFit.cover, iconSize: 28),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Óþekkt útgáfa' : title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  for (final line in lines)
                    Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotACar extends StatelessWidget {
  const _NotACar({required this.title, required this.onRegister});

  final String title;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline_rounded, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '„$title“ virðist ekki vera síða um einn bíl, heldur t.d. um seríu eða lista.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Leita aftur'),
            ),
            TextButton(onPressed: onRegister, child: const Text('Skrá samt með þessu nafni')),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Reyna aftur')),
          ],
        ),
      ),
    );
  }
}
