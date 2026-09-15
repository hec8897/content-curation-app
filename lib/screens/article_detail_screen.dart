import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/store.dart';
import '../design/app_colors.dart';
import '../design/app_text.dart';
import '../widgets/basics.dart';

class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({super.key, required this.articleId, required this.origin});
  final String articleId;
  final String origin;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

enum _SummaryState { loading, done, failed }

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  _SummaryState _state = _SummaryState.loading;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _state = _SummaryState.loading);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      // ponytail: 실패 상태를 목업에서 보이게 하려고 특정 아이템만 실패시킨다.
      setState(() => _state = widget.articleId == 'a3' ? _SummaryState.failed : _SummaryState.done);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = store.item(widget.articleId);
    if (item == null) {
      return const Scaffold(body: Center(child: Text('콘텐츠를 찾을 수 없어요')));
    }
    final siblings = store.siblings(widget.origin, item.id);
    final index = siblings.indexWhere((i) => i.id == item.id);
    final next = index >= 0 && index + 1 < siblings.length ? siblings[index + 1] : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(context, item, siblings.length, index),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.fill,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(item.glyph, style: const TextStyle(fontSize: 44)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(item.title, style: AppText.heading1.c(AppColors.labelNormal)),
                  const SizedBox(height: 8),
                  Text(item.metaLine, style: AppText.label2.c(AppColors.labelAlt)),
                  const SizedBox(height: 20),
                  _summary(item),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: item.kind == ContentKind.youtube ? '유튜브에서 보기' : '원문 보기',
                    onTap: () => _open(item.url),
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 24),
                    Text('다음 콘텐츠', style: AppText.label1.w700.c(AppColors.labelNormal)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => context.pushReplacement('/article/${next.id}?from=${widget.origin}'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgAlt,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            ThumbBox(width: 56, height: 44, radius: 8, glyph: next.glyph),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(next.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.label1.w600.c(AppColors.labelNormal)),
                                  const SizedBox(height: 2),
                                  Text('${next.source} · ${next.kindLabel}',
                                      style: AppText.caption1.c(AppColors.labelAlt)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.labelAssistive),
                          ],
                        ),
                      ),
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

  Widget _header(BuildContext context, ContentItem item, int total, int index) {
    final label = switch (widget.origin) {
      'digest' => '${item.sentAt.month}월 ${item.sentAt.day}일 다이제스트',
      'history' => '알림 히스토리',
      _ => '주제 콘텐츠',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.labelNormal),
          ),
          Expanded(
            child: Text(
              total > 1 ? '$label · ${index + 1} / $total' : label,
              textAlign: TextAlign.center,
              style: AppText.caption1.c(AppColors.labelAlt),
            ),
          ),
          IconButton(
            onPressed: () => showToast(context, '링크를 복사했어요'),
            icon: const Icon(Icons.ios_share_rounded, size: 20, color: AppColors.labelNormal),
          ),
        ],
      ),
    );
  }

  Widget _summary(ContentItem item) {
    if (_state == _SummaryState.failed) {
      return DashedBox(
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
        child: Column(
          children: [
            Text('요약을 만들지 못했어요', style: AppText.headline2.c(AppColors.labelNormal)),
            const SizedBox(height: 4),
            Text('잠시 후 다시 시도해 주세요.', style: AppText.label1.c(AppColors.labelAlt)),
            const SizedBox(height: 14),
            OutlineButton(label: '다시 시도', onTap: _load),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _state == _SummaryState.loading ? '✨ AI 요약 생성 중…' : 'AI 요약',
            style: AppText.label2.w700.c(AppColors.primary),
          ),
          const SizedBox(height: 10),
          if (_state == _SummaryState.loading)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: double.infinity, height: 13, radius: 4),
                SizedBox(height: 8),
                Skeleton(width: double.infinity, height: 13, radius: 4),
                SizedBox(height: 8),
                Skeleton(width: 180, height: 13, radius: 4),
              ],
            )
          else
            Text(item.summary, style: AppText.body2.copyWith(height: 1.65, color: AppColors.labelNeutral)),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showToast(context, '링크를 열 수 없어요');
  }
}
