import 'package:flutter/material.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';
import '../../listings/widgets/listing_photo.dart';

/// Photos of a booking as thumbnails; tapping one shows it large.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.title,
    required this.photos,
    required this.category,
  });

  final String title;
  final List<PhotoOut> photos;
  final ListingCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title (${photos.length})', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        if (photos.isEmpty)
          Text('None', style: theme.textTheme.bodySmall)
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (i, photo) in photos.indexed)
                Semantics(
                  button: true,
                  label: '$title photo ${i + 1}',
                  child: InkWell(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => Dialog(
                        clipBehavior: Clip.antiAlias,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ListingPhoto(
                            url: photo.url,
                            category: category,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: 72,
                      child: ListingPhoto(
                        url: photo.url,
                        category: category,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
