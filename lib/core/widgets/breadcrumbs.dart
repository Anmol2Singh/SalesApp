// lib/core/widgets/breadcrumbs.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class BreadcrumbItem {
  final String label;
  final String? route;

  BreadcrumbItem({required this.label, this.route});
}

class Breadcrumbs extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const Breadcrumbs({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((item) {
            final isLast = item == items.last;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item != items.first) ...[
                  const Icon(Icons.chevron_right, size: 14, color: AppColors.textDisabled),
                  const SizedBox(width: 4),
                ],
                GestureDetector(
                  onTap: isLast || item.route == null
                      ? null
                      : () {
                          context.go(item.route!);
                        },
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                      color: isLast
                          ? AppColors.textPrimary
                          : AppColors.primary,
                      decoration: isLast ? TextDecoration.none : TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
