import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/store.dart';
import '../design/app_colors.dart';
import '../design/app_text.dart';
import '../widgets/basics.dart';
import '../widgets/content_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // ponytail: 목업용 로딩 상태 시연 — 실제로는 리포지토리 future로 대체.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                Expanded(child: Text('큐레이터', style: AppText.heading1.c(AppColors.labelNormal))),
                GestureDetector(
                  onTap: () => context.go('/settings'),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.bgAlt, shape: BoxShape.circle),
                    child: const Icon(Icons.settings_rounded, size: 18, color: AppColors.labelNeutral),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading) ..._loadingBody() else ..._body(),
          ],
        ),
      ),
    );
  }

  List<Widget> _loadingBody() => [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(height: 54, color: AppColors.primaryTint),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: List.generate(
                    2,
                    (_) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          const Skeleton(width: 56, height: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Skeleton(width: double.infinity, height: 14, radius: 4),
                                SizedBox(height: 6),
                                Skeleton(width: 120, height: 12, radius: 4),
                              ],
                            ),
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
        const SizedBox(height: 20),
        const Skeleton(width: 140, height: 20, radius: 4),
        const SizedBox(height: 12),
        const Skeleton(width: double.infinity, height: 68, radius: 16),
        const SizedBox(height: 10),
        const Skeleton(width: double.infinity, height: 68, radius: 16),
      ];

  List<Widget> _body() {
    final digest = store.digest;
    return [
      if (digest.isNotEmpty) _digestCard(digest),
      if (digest.isNotEmpty) const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text('주제', style: AppText.label1.w700.c(AppColors.labelNormal))),
          Text('다음 발송까지 14시간', style: AppText.caption1.c(AppColors.labelAlt)),
        ],
      ),
      const SizedBox(height: 12),
      if (store.topics.isEmpty)
        EmptyState(
          glyph: '🗂',
          title: '아직 주제가 없어요',
          description: '관심 키워드를 등록하면 매일 새 콘텐츠를 모아 보내드려요.',
          actionLabel: '주제 등록하기',
          onAction: _addTopic,
        )
      else
        for (final topic in store.topics) ...[
          _TopicRow(topic: topic, onTap: () => context.go('/topic/${topic.id}')),
          const SizedBox(height: 10),
        ],
      if (store.topics.isNotEmpty)
        GestureDetector(
          onTap: _addTopic,
          child: DashedBox(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text('＋ 주제 추가', style: AppText.label1.w600.c(AppColors.labelAlt)),
            ),
          ),
        ),
    ];
  }

  Widget _digestCard(List<ContentItem> digest) {
    final shown = digest.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('9월 14일 다이제스트', style: AppText.label1.w700.c(Colors.white)),
                const SizedBox(height: 2),
                Text('✉ 이메일 · ${digest.length}건', style: AppText.caption1.c(Colors.white.withValues(alpha: 0.82))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++)
                  ContentCard(
                    item: shown[i],
                    variant: ContentCardVariant.compact,
                    showDivider: i != shown.length - 1,
                    onTap: () => context.push('/article/${shown[i].id}?from=digest'),
                  ),
              ],
            ),
          ),
          AppTextButton(
            label: '${digest.length}건 모두 보기',
            onTap: () => context.go('/history'),
          ),
        ],
      ),
    );
  }

  void _addTopic() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.dimmer,
      builder: (sheetContext) => SheetScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('주제 추가', style: AppText.headline2.c(AppColors.labelNormal)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: AppText.body2.c(AppColors.labelNormal),
              decoration: InputDecoration(
                hintText: '예: LLM 에이전트',
                hintStyle: AppText.body2.c(AppColors.labelAssistive),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.lineSolid),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: '주제 등록하기',
              onTap: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                store.addTopic(name);
                Navigator.pop(sheetContext);
                showToast(context, '주제를 추가했어요');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.onTap});
  final Topic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = topic.sources.isEmpty;
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.name,
                      style: AppText.label1.w600
                          .c(empty ? AppColors.labelAssistive : AppColors.labelNormal),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      empty
                          ? '소스 0 — 소스를 추가해 주세요'
                          : '소스 ${topic.sources.length} · 새 콘텐츠 ${topic.items.length}건',
                      style: AppText.caption1
                          .c(empty ? AppColors.labelAssistive : AppColors.labelAlt),
                    ),
                  ],
                ),
              ),
              if (!topic.notify) ...[
                const PillBadge('알림 OFF'),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.labelAssistive),
            ],
          ),
        ),
      ),
    );
  }
}
