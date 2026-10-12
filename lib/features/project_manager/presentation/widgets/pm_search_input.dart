import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/pm_tokens.dart';

class PmSearchInput extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String hintText;
  final VoidCallback? onClear;

  const PmSearchInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText = 'Search projects, sites, mobile...',
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: pm.card,
        borderRadius: BorderRadius.circular(pm.radiusMd),
        border: Border.all(color: pm.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 16, color: pm.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: value)
                ..selection = TextSelection.collapsed(offset: value.length),
              onChanged: onChanged,
              style: TextStyle(fontSize: 13, color: pm.foreground),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(fontSize: 13, color: pm.mutedForeground),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (value.isNotEmpty)
            InkWell(
              onTap: () {
                onChanged('');
                onClear?.call();
              },
              child: Icon(LucideIcons.x, size: 16, color: pm.mutedForeground),
            ),
        ],
      ),
    );
  }
}
