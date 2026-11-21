import 'package:material_ui/material_ui.dart';

import 'car_photo.dart';

/// Mynd af bíl. Myndir eru geymdar í skyndiminni svo safnið virki án nets.
class CarImage extends StatelessWidget {
  const CarImage({super.key, this.url, this.fit = BoxFit.contain, this.iconSize = 40});

  final String? url;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.directions_car_filled_rounded,
          size: iconSize,
          color: colors.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );

    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) return placeholder;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.surfaceContainerLowest, colors.surfaceContainerHigh],
        ),
      ),
      child: Image(
        image: imageProviderFor(imageUrl),
        fit: fit,
        frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : placeholder,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}
