import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/data/models/data_models.dart';
import 'package:salesapp/features/customer_app/features/service_request/screens/service_booking_flow.dart';

ImageProvider _getProductImageProvider(String url, [String? category]) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return NetworkImage(url);
  }
  final cat = (category ?? '').toLowerCase();
  if (cat.contains('boiler')) {
    return const NetworkImage('https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=800&auto=format&fit=crop');
  }
  if (cat.contains('thermostat')) {
    return const NetworkImage('https://images.unsplash.com/photo-1545259742-b4fd8fea67e4?w=800&auto=format&fit=crop');
  }
  return const NetworkImage(
    'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=800&auto=format&fit=crop',
  );
}

Widget _buildProductThumbnail(Product product) {
  final url = product.imageUrl.trim();
  final isValidUrl = url.startsWith('http://') || url.startsWith('https://');

  Widget fallbackIcon() {
    final cat = product.category.toLowerCase();
    final name = product.productName.toLowerCase();
    IconData icon = Icons.solar_power_rounded;
    if (cat.contains('heat') || name.contains('heat pump')) {
      icon = Icons.heat_pump_rounded;
    } else if (cat.contains('barrier') || name.contains('boom barrier') || name.contains('barrier')) {
      icon = Icons.fence_rounded;
    } else if (cat.contains('boiler') || name.contains('boiler') || name.contains('water heater')) {
      icon = Icons.water_drop_rounded;
    }

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Icon(icon, color: AppColors.primary, size: 36),
      ),
    );
  }

  if (!isValidUrl) {
    return fallbackIcon();
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Image.network(
      url,
      width: 76,
      height: 76,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallbackIcon(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: 76,
          height: 76,
          color: AppColors.primary.withOpacity(0.05),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    ),
  );
}

/// A prominent, feature-rich card for displaying the customer's primary or single equipment
class HeroProductCard extends StatelessWidget {
  final Product product;

  const HeroProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isAmcActive = product.amcStatus.toLowerCase() == 'active';
    final bool hasAmc = product.amcStatus.isNotEmpty && product.amcStatus.toLowerCase() != 'none';
    final bool isWarrantyValid = DateTime.now().isBefore(product.warrantyExpiryDate);

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Badges Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Category Chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        () {
                          final cat = product.category.toLowerCase();
                          final name = product.productName.toLowerCase();
                          if (cat.contains('barrier') || name.contains('barrier')) {
                            return Icons.fence_rounded;
                          } else if (cat.contains('boiler') || name.contains('water heater') || cat.contains('swh')) {
                            return Icons.water_drop_rounded;
                          } else if (cat.contains('heat') || name.contains('heat pump')) {
                            return Icons.heat_pump_rounded;
                          }
                          return Icons.solar_power_rounded;
                        }(),
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      product.category.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),

                // AMC / Warranty Status Pill
                Row(
                  children: [
                    if (hasAmc) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAmcActive
                              ? const Color(0xFF10B981).withOpacity(0.12)
                              : const Color(0xFFEF4444).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isAmcActive
                                ? const Color(0xFF10B981).withOpacity(0.3)
                                : const Color(0xFFEF4444).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAmcActive ? Icons.verified_rounded : Icons.warning_amber_rounded,
                              size: 12,
                              color: isAmcActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAmcActive ? 'AMC ACTIVE' : 'AMC EXPIRED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isAmcActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isWarrantyValid
                            ? const Color(0xFF0284C7).withOpacity(0.12)
                            : Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isWarrantyValid ? 'Under Warranty' : 'Out of Warranty',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isWarrantyValid ? const Color(0xFF0284C7) : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Main Product Info Row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image Thumbnail
                _buildProductThumbnail(product),
                const SizedBox(width: 14),

                // Name & Specs
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.productName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      if (product.modelNumber.isNotEmpty)
                        Text(
                          'Model: ${product.modelNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (product.serialNumber.isNotEmpty)
                        Text(
                          'S/N: ${product.serialNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Installed: ${DateFormat('dd MMM yyyy').format(product.purchasedDate)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Action Buttons Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Request Service Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => ServiceBookingFlow(preselectedProductId: product.productId),
                      );
                    },
                    icon: const Icon(Icons.build_rounded, size: 15),
                    label: const Text(
                      'Request Service',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // View Details Button
                OutlinedButton(
                  onPressed: () => context.push('/product/${product.productId}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
                    side: BorderSide(color: borderColor, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Details',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard card for multi-product horizontal carousels
class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final isAmcActive = product.amcStatus.toLowerCase() == 'active';

    return Container(
      width: 220,
      height: 270,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.primary.withOpacity(0.08),
        image: DecorationImage(
          image: _getProductImageProvider(product.imageUrl, product.category),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Dark gradient overlay for readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),

            // Top Status Badges (AMC / Category)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (product.amcStatus.isNotEmpty && product.amcStatus != 'none')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isAmcActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAmcActive ? 'AMC Active' : 'AMC Expired',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),

            // Tap area
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/product/${product.productId}'),
                child: const SizedBox.expand(),
              ),
            ),

            // Bottom Frosted Glass Info Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.productName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          product.modelNumber.isNotEmpty ? 'Model: ${product.modelNumber}' : 'Category: ${product.category.toUpperCase()}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified, color: Color(0xFF38BDF8), size: 13),
                                SizedBox(width: 4),
                                Text(
                                  'Installed',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Product card for advertisement catalog items
class AdvProductCard extends StatelessWidget {
  final Product product;

  const AdvProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 270,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.primary.withOpacity(0.08),
        image: DecorationImage(
          image: _getProductImageProvider(product.imageUrl, product.category),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Dark gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                  ),
                ),
              ),
            ),

            // Container for ripple effect and tap detection
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/product/${product.productId}'),
                child: const SizedBox.expand(),
              ),
            ),

            // Bottom Info Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.productName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          product.modelNumber.isNotEmpty ? product.modelNumber : product.category.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            const Text(
                              '5.0',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
