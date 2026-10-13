import 'package:flutter/material.dart';

class PmStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String description;
  final Widget icon;
  final Color? iconBgColor;
  final Color? iconColor;
  final Color? accentColor;

  const PmStatCard({
    super.key,
    required this.title,
    required this.value,
    this.description = '',
    required this.icon,
    this.iconBgColor,
    this.iconColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final fgBubble = iconColor ?? accentColor ?? const Color(0xFF0284C7);
    final bgBubble = iconBgColor ?? (accentColor != null ? accentColor!.withOpacity(0.12) : const Color(0xFFE0F2FE));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bgBubble,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(color: fgBubble, size: 16),
                    child: icon,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.6,
              ),
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              description,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
