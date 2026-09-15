import 'package:flutter/material.dart';

import '../data/store.dart';
import '../design/app_colors.dart';
import '../design/app_text.dart';
import 'basics.dart';

enum ContentCardVariant { compact, list }

class ContentCard extends StatelessWidget {
  const ContentCard({
    super.key,
    required this.item,
    this.variant = ContentCardVariant.list,
    this.onTap,
    this.showDivider = true,
  });

  final ContentItem item;
  final ContentCardVariant variant;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return variant == ContentCardVariant.compact ? _compact() : _list();
  }

  Widget _compact() {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primary.withValues(alpha: 0.08),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: showDivider
            ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.fill)))
            : null,
        child: Row(
          children: [
            ThumbBox(width: 56, height: 44, radius: 8, glyph: item.glyph),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label1.w600.c(AppColors.labelNormal),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.source} · ${item.kindLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption1.c(AppColors.labelAlt),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.labelAssistive),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lineSolid),
        boxShadow: cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ThumbBox(width: 96, height: 74, radius: 12, glyph: item.glyph),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SourceBadge(item.source),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label1.w600.c(AppColors.labelNormal),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.kindLabel} · ${item.dateLabel}',
                      style: AppText.caption1.c(AppColors.labelAlt),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
