import 'package:flutter/material.dart';
import '../theme/pm_tokens.dart';
import 'pm_card.dart';

class PmStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String description;
  final Widget icon;
  final Color? accentColor;

  const PmStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;
    final color = accentColor ?? pm.primary;

    return PmCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: pm.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconTheme(
                  data: IconThemeData(color: color, size: 18),
                  child: icon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: pm.foreground,
              letterSpacing: -0.5,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: pm.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
