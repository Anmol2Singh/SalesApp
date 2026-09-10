import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';

class ImageWithFallback extends StatelessWidget {
  final String? imageUrl;
  final Widget? fallbackWidget;
  final BoxFit fit;
  final double? width;
  final double? height;

  const ImageWithFallback({
    super.key,
    this.imageUrl,
    this.fallbackWidget,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = fallbackWidget ??
        Container(
          width: width,
          height: height,
          color: AppColors.bgSecondary,
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.textSecondary,
              size: 32,
            ),
          ),
        );

    if (imageUrl == null || imageUrl!.isEmpty) {
      return fallback;
    }

    // Handing asset image vs network image
    if (imageUrl!.startsWith('assets/')) {
      return Image.asset(
        imageUrl!,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: AppColors.bgSecondary,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => fallback,
    );
  }
}
