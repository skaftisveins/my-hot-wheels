import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../models/car.dart';
import '../widgets/car_image.dart';
import 'car_form_screen.dart';

/// Sýnir einn bíl í einu. Hægt er að fletta á milli bíla með því að strjúka
/// til hliðar eða með örvunum neðst.
class CarDetailScreen extends StatefulWidget {
  const CarDetailScreen({super.key, required this.carIds, required this.initialIndex});

  final List<String> carIds;
  final int initialIndex;

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _delete(Car car) async {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(cars.length > 1 ? '${index + 1} af ${cars.length}' : car.name),
        actions: [
          IconButton(
            tooltip: car.favorite ? 'Taka úr uppáhalds' : 'Setja í uppáhalds',
            icon: Icon(car.favorite ? Icons.star_rounded : Icons.star_outline_rounded),
            onPressed: () => store.toggleFavorite(car.id),
          ),
          IconButton(
            tooltip: 'Breyta',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => CarFormScreen(car: car, isNew: false))),
          ),
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () => _delete(car),
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
      body: PageView.builder(
        controller: _controller,
        itemCount: cars.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => _CarPage(car: cars[i]),
      ),
      bottomNavigationBar: cars.length < 2
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Fyrri bíll',
                      onPressed: index > 0 ? () => _goTo(index - 1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (index + 1) / cars.length,
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Næsti bíll',
                      onPressed: index < cars.length - 1 ? () => _goTo(index + 1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _CarPage extends StatelessWidget {
  const _CarPage({required this.car});

  final Car car;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final store = AppScope.readStore(context);
    final wikiUrl = car.wikiUrl;

    final details = <(String, String?)>[
      ('Árgerð', car.year?.toString()),
      ('Sería', [car.series, car.seriesNumber].whereType<String>().join(' · ')),
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
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Hero(
            tag: 'car-${car.id}',
            child: CarImage(url: car.imageUrl, iconSize: 96),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                car.name,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
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
            ],
          ),
        ),
        if (details.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card.outlined(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (final (label, value) in details)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 110,
                              child: Text(
                                label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(child: Text(value!, style: theme.textTheme.bodyMedium)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (car.notes != null && car.notes!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Icon(Icons.sticky_note_2_outlined, color: colors.onSurfaceVariant),
                    Expanded(child: Text(car.notes!, style: theme.textTheme.bodyLarge)),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'Skráður ${MaterialLocalizations.of(context).formatMediumDate(car.addedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        if (wikiUrl != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(wikiUrl, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Skoða á Hot Wheels Wiki'),
              ),
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
