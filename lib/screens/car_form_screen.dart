import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../data/collection_store.dart';
import '../models/car.dart';
import '../widgets/car_image.dart';
import '../widgets/own_photo.dart';

/// Síðasta skrefið í skráningu (og skjárinn til að breyta bíl).
/// Reitirnir eru fylltir út fyrir fram með gögnum af wiki ef þau eru til.
class CarFormScreen extends StatefulWidget {
  const CarFormScreen({super.key, required this.car, required this.isNew});

  final Car car;
  final bool isNew;

  @override
  State<CarFormScreen> createState() => _CarFormScreenState();
}

class _CarFormScreenState extends State<CarFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late CarCondition _condition = widget.car.condition;
  late int _quantity = widget.car.quantity;
  late bool _favorite = widget.car.favorite;
  late String? _ownPhoto = widget.car.ownPhoto;
  bool _saving = false;

  Future<void> _takePhoto() async {
    final id = await takeOwnPhoto(context);
    if (id != null && mounted) setState(() => _ownPhoto = id);
  }

  TextEditingController _c(String key) => _fields[key]!;

  @override
  void initState() {
    super.initState();
    final car = widget.car;
    _fields = {
      'name': car.name,
      'year': car.year?.toString(),
      'series': car.series,
      'seriesNumber': car.seriesNumber,
      'collectorNumber': car.collectorNumber,
      'color': car.color,
      'tampo': car.tampo,
      'wheelType': car.wheelType,
      'toyNumber': car.toyNumber,
      'baseColor': car.baseColor,
      'windowColor': car.windowColor,
      'interiorColor': car.interiorColor,
      'country': car.country,
      'designer': car.designer,
      'imageUrl': car.imageUrl,
      'notes': car.notes,
    }.map((key, value) => MapEntry(key, TextEditingController(text: value ?? '')));
    _c('imageUrl').addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _value(String key) {
    final text = _c(key).text.trim();
    return text.isEmpty ? null : text;
  }

  Car _buildCar() => Car(
    id: widget.isNew ? CollectionStore.newId() : widget.car.id,
    addedAt: widget.isNew ? DateTime.now() : widget.car.addedAt,
    name: _value('name')!,
    castingTitle: widget.car.castingTitle,
    year: int.tryParse(_value('year') ?? ''),
    series: _value('series'),
    seriesNumber: _value('seriesNumber'),
    collectorNumber: _value('collectorNumber'),
    color: _value('color'),
    tampo: _value('tampo'),
    wheelType: _value('wheelType'),
    toyNumber: _value('toyNumber'),
    baseColor: _value('baseColor'),
    windowColor: _value('windowColor'),
    interiorColor: _value('interiorColor'),
    country: _value('country'),
    designer: _value('designer'),
    imageUrl: _value('imageUrl'),
    ownPhoto: _ownPhoto,
    notes: _value('notes'),
    condition: _condition,
    quantity: _quantity,
    favorite: _favorite,
  );

  /// Bíll í safninu sem er eins (sama gerð, ár og litur), ef hann er til.
  Car? _findDuplicate(CollectionStore store) {
    if (!widget.isNew) return null;
    final year = int.tryParse(_value('year') ?? '');
    final color = _value('color')?.toLowerCase();
    return store
        .sameModel(widget.car.castingTitle, _value('name') ?? widget.car.name)
        .where((c) => c.year == year && c.color?.toLowerCase() == color)
        .firstOrNull;
  }

  void _finish(String message) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final store = AppScope.readStore(context);
    try {
      final car = _buildCar();
      if (widget.isNew) {
        await store.add(car);
        if (mounted) _finish('${car.name} er kominn í safnið! 🏁');
      } else {
        await store.update(car);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Tókst ekki að vista bílinn: $e')));
    }
  }

  Future<void> _addCopy(Car existing) async {
    final store = AppScope.readStore(context);
    await store.setQuantity(existing.id, existing.quantity + 1);
    if (mounted) _finish('Nú áttu ${existing.quantity + 1} eintök af ${existing.name}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final duplicate = _findDuplicate(AppScope.storeOf(context));
    final imageUrl = _value('imageUrl');

    Widget field(
      String key,
      String label, {
      IconData? icon,
      TextInputType? keyboard,
      String? Function(String?)? validator,
      int maxLines = 1,
    }) {
      return TextFormField(
        controller: _c(key),
        keyboardType: keyboard,
        maxLines: maxLines,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        validator: validator,
        decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isNew ? 'Nýr bíll' : 'Breyta bíl')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _PhotoPanel(
                image: _ownPhoto != null ? 'local:$_ownPhoto' : imageUrl,
                isOwnPhoto: _ownPhoto != null,
                canUseWikiPhoto: _ownPhoto != null && imageUrl != null,
                onTakePhoto: _takePhoto,
                onUseWikiPhoto: () => setState(() => _ownPhoto = null),
              ),
            ),
            if (duplicate != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card.filled(
                  color: colors.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Þú átt þennan bíl nú þegar!',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Viltu frekar bæta við eintaki af þeim sem er til?',
                          style: TextStyle(color: colors.onSecondaryContainer),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _saving ? null : () => _addCopy(duplicate),
                          icon: const Icon(Icons.exposure_plus_1_rounded),
                          label: Text('Bæta við eintaki (á nú ${duplicate.quantity})'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Column(
              spacing: 12,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field(
                  'name',
                  'Nafn bílsins *',
                  icon: Icons.directions_car_outlined,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Bíllinn þarf að heita eitthvað' : null,
                ),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: field(
                        'year',
                        'Árgerð',
                        icon: Icons.calendar_today_outlined,
                        keyboard: TextInputType.number,
                        validator: (v) {
                          final text = (v ?? '').trim();
                          if (text.isEmpty) return null;
                          final year = int.tryParse(text);
                          return year == null || year < 1968 || year > DateTime.now().year + 2
                              ? 'Ógilt ár'
                              : null;
                        },
                      ),
                    ),
                    Expanded(child: field('color', 'Litur', icon: Icons.palette_outlined)),
                  ],
                ),
                field('series', 'Sería', icon: Icons.flag_outlined),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(child: field('seriesNumber', 'Nr. í seríu')),
                    Expanded(child: field('collectorNumber', 'Safnnúmer')),
                  ],
                ),
                field('tampo', 'Skreyting (tampo)', icon: Icons.auto_awesome_outlined),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(child: field('wheelType', 'Felgur')),
                    Expanded(child: field('toyNumber', 'Vörunúmer')),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Ástand', style: theme.textTheme.titleSmall),
                SegmentedButton<CarCondition>(
                  segments: const [
                    ButtonSegment(
                      value: CarCondition.loose,
                      icon: Icon(Icons.toys_outlined),
                      label: Text('Laus'),
                    ),
                    ButtonSegment(
                      value: CarCondition.carded,
                      icon: Icon(Icons.inventory_2_outlined),
                      label: Text('Í pakkningu'),
                    ),
                  ],
                  selected: {_condition},
                  onSelectionChanged: (s) => setState(() => _condition = s.first),
                ),
                Row(
                  children: [
                    Expanded(child: Text('Fjöldi eintaka', style: theme.textTheme.titleSmall)),
                    IconButton.outlined(
                      tooltip: 'Fækka',
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$_quantity',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Fjölga',
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Uppáhalds'),
                  secondary: Icon(_favorite ? Icons.star_rounded : Icons.star_outline_rounded),
                  value: _favorite,
                  onChanged: (v) => setState(() => _favorite = v),
                ),
                field('notes', 'Athugasemdir', icon: Icons.sticky_note_2_outlined, maxLines: 4),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 4),
                  title: const Text('Fleiri upplýsingar'),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    Column(
                      spacing: 12,
                      children: [
                        Row(
                          spacing: 12,
                          children: [
                            Expanded(child: field('baseColor', 'Botn')),
                            Expanded(child: field('windowColor', 'Rúður')),
                          ],
                        ),
                        Row(
                          spacing: 12,
                          children: [
                            Expanded(child: field('interiorColor', 'Innrétting')),
                            Expanded(child: field('country', 'Framleitt í')),
                          ],
                        ),
                        field('designer', 'Hönnuður'),
                        field('imageUrl', 'Slóð á mynd', keyboard: TextInputType.url),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _saving ? null : _save,
            icon: Icon(widget.isNew ? Icons.garage_rounded : Icons.check_rounded),
            label: Text(widget.isNew ? 'Setja í safnið' : 'Vista breytingar'),
          ),
        ),
      ),
    );
  }
}

/// Myndin efst í forminu, með hnöppum til að taka eigin mynd eða nota wiki-myndina.
class _PhotoPanel extends StatelessWidget {
  const _PhotoPanel({
    required this.image,
    required this.isOwnPhoto,
    required this.canUseWikiPhoto,
    required this.onTakePhoto,
    required this.onUseWikiPhoto,
  });

  final String? image;
  final bool isOwnPhoto;
  final bool canUseWikiPhoto;
  final VoidCallback onTakePhoto;
  final VoidCallback onUseWikiPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (image == null) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(120),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onTakePhoto,
        icon: const Icon(Icons.photo_camera_rounded, size: 32),
        label: const Text('Taka mynd af bílnum'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CarImage(url: image, iconSize: 64),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilledButton.tonalIcon(
              onPressed: onTakePhoto,
              icon: const Icon(Icons.photo_camera_rounded),
              label: Text(isOwnPhoto ? 'Taka nýja mynd' : 'Taka eigin mynd'),
            ),
            if (canUseWikiPhoto)
              TextButton.icon(
                onPressed: onUseWikiPhoto,
                icon: const Icon(Icons.public_rounded),
                label: const Text('Nota wiki-myndina'),
              ),
          ],
        ),
        if (isOwnPhoto)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Myndin er geymd í þessu tæki.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
