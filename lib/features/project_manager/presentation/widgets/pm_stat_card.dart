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
    final bgBubble = iconBgColor ?? (accentColor != null ? accentColor!.withValues(alpha: 0.12) : const Color(0xFFE0F2FE));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Top accent indicator line
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 3.5,
              child: Container(
                color: fgBubble,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: bgBubble,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: fgBubble.withValues(alpha: 0.2), width: 1),
                        ),
                        child: Center(
                          child: IconTheme(
                            data: IconThemeData(color: fgBubble, size: 17),
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
                        fontFamily: 'Inter',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
