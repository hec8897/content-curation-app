import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/store.dart';
import '../design/app_colors.dart';
import '../design/app_text.dart';
import '../widgets/basics.dart';
import '../widgets/content_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final batches = store.history;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text('알림 히스토리', style: AppText.heading1.c(AppColors.labelNormal)),
              const SizedBox(height: 16),
              if (batches.isEmpty)
                const EmptyState(
                  glyph: '🔔',
                  title: '아직 발송된 알림이 없어요',
                  description: '주제와 소스를 등록하면 다음 발송부터 여기에 쌓여요.',
                )
              else
                for (var i = 0; i < batches.length; i++) ...[
                  _BatchCard(batch: batches[i], latest: i == 0),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({required this.batch, required this.latest});
  final NotificationBatch batch;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: latest ? AppColors.primary : AppColors.lineSolid,
          width: latest ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${batch.dateLabel} 발송', style: AppText.label1.w700.c(AppColors.labelNormal)),
          const SizedBox(height: 2),
          Text('✉ ${batch.channel} · ${batch.items.length}건',
              style: AppText.caption1.c(AppColors.labelAlt)),
          const SizedBox(height: 6),
          for (var i = 0; i < batch.items.length; i++)
            ContentCard(
              item: batch.items[i],
              variant: ContentCardVariant.compact,
              showDivider: i != batch.items.length - 1,
              onTap: () => context.push('/article/${batch.items[i].id}?from=history'),
            ),
        ],
      ),
    );
  }
}
