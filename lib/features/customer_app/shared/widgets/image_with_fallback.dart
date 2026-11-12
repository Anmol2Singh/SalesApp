import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';

class ImageWithFallback extends StatelessWidget {
  final String? imageUrl;
  final Widget? fallbackWidget;
  final BoxFit fit;
  final double? width;
  final double? height;
  final String? category;

  const ImageWithFallback({
    super.key,
    this.imageUrl,
    this.fallbackWidget,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildDefaultFallback() {
      IconData icon = Icons.solar_power_rounded;
      final cat = (category ?? '').toLowerCase();
      if (cat.contains('heat') || cat.contains('pump')) {
        icon = Icons.heat_pump_rounded;
      } else if (cat.contains('boiler') || cat.contains('water') || cat.contains('swh')) {
        icon = Icons.water_drop_rounded;
      } else if (cat.contains('barrier') || cat.contains('boom')) {
        icon = Icons.sensor_door_outlined;
      }

      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFF1E1B4B), const Color(0xFF312E81)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFF59E0B),
                  size: 32,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'IZYHEAT',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final fallback = fallbackWidget ?? buildDefaultFallback();

    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return fallback;
    }

    final cleanUrl = imageUrl!.trim();

    // Handling asset image vs network image
    if (cleanUrl.startsWith('assets/')) {
      return Image.asset(
        cleanUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    Widget buildLoadingPlaceholder() {
      return Container(
        width: width,
        height: height,
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
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
      );
    }

    // On Flutter Web, use Image.network directly to avoid CORS byte-caching issues
    if (kIsWeb) {
      return Image.network(
        cleanUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return buildLoadingPlaceholder();
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: cleanUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) => buildLoadingPlaceholder(),
      errorWidget: (context, url, error) => Image.network(
        cleanUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return buildLoadingPlaceholder();
        },
      ),
    );
  }
}
