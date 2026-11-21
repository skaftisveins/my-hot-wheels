import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../data/collection_store.dart';
import '../services/photo_store.dart';

/// Sýnir ráð um myndatöku, opnar myndavélina (eða myndasafnið) og vistar
/// myndina á tækinu. Skilar auðkenni myndarinnar, eða `null` ef hætt var við.
Future<String?> takeOwnPhoto(BuildContext context) async {
  final picked = await showModalBottomSheet<Future<XFile?>>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _PhotoTips(),
  );
  if (picked == null) return null;

  final XFile? file;
  try {
    file = await picked;
  } catch (_) {
    if (context.mounted) _error(context, 'Tókst ekki að opna myndavélina.');
    return null;
  }
  if (file == null) return null;

  try {
    final bytes = await file.readAsBytes();
    final id = CollectionStore.newId();
    await PhotoStore.instance.write(id, bytes);
    return id;
  } catch (_) {
    if (context.mounted) _error(context, 'Tókst ekki að vista myndina á tækinu.');
    return null;
  }
}

void _error(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

class _PhotoTips extends StatelessWidget {
  const _PhotoTips();

  /// Myndavélin verður að opnast beint úr smellinum (Safari á iPhone leyfir
  /// ekki annað), svo valið hefst strax og loforðið er sent til baka.
  static Future<XFile?> _pick(ImageSource source) => ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 88,
    preferredCameraDevice: CameraDevice.rear,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const tips = [
      (Icons.description_outlined, 'Settu bílinn á hvítt blað eða ljósan, sléttan flöt.'),
      (Icons.wb_sunny_outlined, 'Taktu myndina í góðri birtu, beint frá hlið.'),
      (Icons.crop_free_rounded, 'Láttu bílinn fylla vel út í myndina.'),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Taktu mynd af bílnum', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Appið klippir bakgrunninn burt svo bíllinn standi sjálfur á sviðinu.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final (icon, text) in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  spacing: 12,
                  children: [
                    Icon(icon, color: theme.colorScheme.primary),
                    Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => Navigator.pop(context, _pick(ImageSource.camera)),
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Taka mynd'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(context, _pick(ImageSource.gallery)),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Velja úr myndasafni'),
            ),
          ],
        ),
      ),
    );
  }
}
