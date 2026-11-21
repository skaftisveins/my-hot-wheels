import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../data/collection_store.dart';
import '../widgets/car_card.dart';
import 'add_car_search_screen.dart';
import 'car_detail_screen.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  CarFilter _filter = CarFilter.all;
  CarSort _sort = CarSort.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddCar() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AddCarSearchScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.storeOf(context);
    final cars = store.query(search: _search, filter: _filter, sort: _sort);
    final theme = Theme.of(context);
    final isEmpty = store.cars.isEmpty;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddCar,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Skrá bíl'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: const Text('Bílasafnið'),
            actions: [
              if (!isEmpty)
                PopupMenuButton<CarSort>(
                  tooltip: 'Raða',
                  icon: const Icon(Icons.sort_rounded),
                  initialValue: _sort,
                  onSelected: (sort) => setState(() => _sort = sort),
                  itemBuilder: (_) => [
                    for (final sort in CarSort.values)
                      PopupMenuItem(value: sort, child: Text(sort.label)),
                  ],
                ),
            ],
          ),
          if (isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _EmptyCollection(onAdd: _openAddCar))
          else ...[
            SliverToBoxAdapter(child: _StatsRow(store: store)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Leita í safninu…',
                  leading: const Icon(Icons.search_rounded),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (value) => setState(() => _search = value),
                  trailing: [
                    if (_search.isNotEmpty)
                      IconButton(
                        tooltip: 'Hreinsa',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  spacing: 8,
                  children: [
                    for (final filter in CarFilter.values)
                      ChoiceChip(
                        label: Text(filter.label),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                  ],
                ),
              ),
            ),
            if (cars.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Enginn bíll passar við leitina.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: cars.length,
                  itemBuilder: (context, index) => CarCard(
                    car: cars[index],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CarDetailScreen(
                          carIds: [for (final c in cars) c.id],
                          initialIndex: index,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.store});

  final CollectionStore store;

  @override
  Widget build(BuildContext context) {
    final oldest = store.oldestYear;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: _Stat(value: '${store.totalCars}', label: 'bílar'),
          ),
          Expanded(
            child: _Stat(value: '${store.distinctModels}', label: 'gerðir'),
          ),
          Expanded(
            child: _Stat(value: '${store.favoriteCount}', label: 'uppáhalds'),
          ),
          if (oldest != null)
            Expanded(
              child: _Stat(value: '$oldest', label: 'elsti'),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          children: [
            FittedBox(
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: colors.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.garage_rounded, size: 96, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Bílskúrinn er tómur', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Skráðu fyrsta bílinn. Þú getur leitað að honum á Hot Wheels Wiki '
              'og fengið mynd og allar upplýsingar sjálfkrafa.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Skrá fyrsta bílinn'),
            ),
          ],
        ),
      ),
    );
  }
}
