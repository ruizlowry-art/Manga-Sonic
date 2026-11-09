import 'package:flutter/material.dart';
import 'package:manga_sonic/utils/source_registry.dart';

class SourceTag extends StatelessWidget {
  final String sourceId;
  final Color accentColor;
  final bool showIcon;

  const SourceTag({
    super.key,
    required this.sourceId,
    this.accentColor = Colors.deepPurpleAccent,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            const Icon(
              Icons.source_outlined,
              size: 12,
              color: Colors.white70,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            SourceRegistry.getDisplayName(sourceId),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
