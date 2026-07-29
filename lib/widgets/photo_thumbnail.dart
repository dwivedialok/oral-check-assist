import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../models/photo_capture.dart';
import 'quality_indicator.dart';

/// Thumbnail widget for displaying captured photos in review
class PhotoThumbnail extends StatelessWidget {
  final PhotoCapture photo;
  final VoidCallback? onTap;
  final VoidCallback? onRetake;
  /// Shown on captured photos (e.g. "Retake" for poor quality, "Replace" when acceptable).
  final String? retakeActionLabel;
  /// Empty slot: opens capture for this angle (e.g. from Review Photos).
  final VoidCallback? onCaptureEmpty;
  final String? captureEmptyLabel;
  final bool showRetakeButton;
  final bool selected;

  const PhotoThumbnail({
    super.key,
    required this.photo,
    this.onTap,
    this.onRetake,
    this.retakeActionLabel,
    this.onCaptureEmpty,
    this.captureEmptyLabel,
    this.showRetakeButton = true,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected 
                ? Theme.of(context).primaryColor 
                : Colors.grey.shade300,
            width: selected ? 3 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo or placeholder (on web use bytes when available)
              if (photo.isCaptured && (photo.imageBytes != null || photo.image != null))
                photo.imageBytes != null
                    ? Image.memory(
                        photo.imageBytes!,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        photo.image! as dynamic,
                        fit: BoxFit.cover,
                      )
              else
                Container(
                  color: Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 28,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Not captured',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

              // Capture CTA for empty slots (review screen)
              if (!photo.isCaptured && onCaptureEmpty != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: GestureDetector(
                        onTap: onCaptureEmpty,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_a_photo_outlined,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                captureEmptyLabel ?? 'Capture',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Photo type / user-selected label at top.
              //
              // Display resolution (purely presentational, independent of
              // inference and risk):
              // - if the user set a label, show it (custom text preserved
              //   when [OralPhotoLabel.custom]);
              // - otherwise show the localized slot name, matching legacy
              //   behavior (AC7 legacy fallback).
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Builder(
                    builder: (ctx) {
                      final l10n = AppLocalizations.of(ctx);
                      final text = l10n != null
                          ? photoCaptureEffectiveLabelText(l10n, photo)
                          : photo.effectiveLabelDisplay;
                      return Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
              ),

              // Quality indicator at bottom
              if (photo.isCaptured)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CompactQualityIndicator(metrics: photo.qualityMetrics),
                        if (showRetakeButton && photo.isCaptured && onRetake != null)
                          GestureDetector(
                            onTap: onRetake,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.refresh, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    retakeActionLabel ?? 'Retake',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Checkmark for acceptable photos
              if (photo.isAcceptable)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),

              // Warning for poor quality
              if (photo.isCaptured && !photo.isAcceptable)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid of photo thumbnails for review screen
class PhotoThumbnailGrid extends StatelessWidget {
  final List<PhotoCapture> photos;
  final Function(PhotoType)? onPhotoTap;
  final Function(PhotoType)? onRetake;
  final String retakeLabel;
  final String replaceLabel;
  /// When set, empty slots show a capture button that calls this with the slot type.
  final Function(PhotoType)? onCaptureEmpty;
  final String? captureEmptyLabel;
  final int crossAxisCount;
  final double spacing;

  const PhotoThumbnailGrid({
    super.key,
    required this.photos,
    this.onPhotoTap,
    this.onRetake,
    required this.retakeLabel,
    required this.replaceLabel,
    this.onCaptureEmpty,
    this.captureEmptyLabel,
    this.crossAxisCount = 2,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 0.85,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return PhotoThumbnail(
          photo: photo,
          onTap: onPhotoTap != null ? () => onPhotoTap!(photo.type) : null,
          onRetake: onRetake != null ? () => onRetake!(photo.type) : null,
          retakeActionLabel:
              photo.isAcceptable ? replaceLabel : retakeLabel,
          onCaptureEmpty: !photo.isCaptured && onCaptureEmpty != null
              ? () => onCaptureEmpty!(photo.type)
              : null,
          captureEmptyLabel: captureEmptyLabel,
        );
      },
    );
  }
}
