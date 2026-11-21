import 'package:material_ui/material_ui.dart';

import '../models/car.dart';
import 'car_image.dart';

class CarCard extends StatelessWidget {
  const CarCard({super.key, required this.car, required this.onTap});

  final Car car;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtitle = [car.year?.toString(), car.color].whereType<String>().join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'car-${car.id}',
                    child: CarImage(url: car.displayImage),
                  ),
                  if (car.favorite)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _Badge(
                        color: colors.tertiaryContainer,
                        child: Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: colors.onTertiaryContainer,
                        ),
                      ),
                    ),
                  if (car.quantity > 1)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _Badge(
                        color: colors.primary,
                        child: Text(
                          '×${car.quantity}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle.isEmpty ? car.condition.label : subtitle,
                    maxLines: 1,
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

class _Badge extends StatelessWidget {
  const _Badge({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Color(0x33000000))],
      ),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), child: child),
    );
  }
}
