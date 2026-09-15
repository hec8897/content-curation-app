import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/store.dart';
import '../design/app_colors.dart';
import '../design/app_text.dart';
import '../widgets/basics.dart';
import '../widgets/content_card.dart';

enum _Filter { all, youtube, article }

class TopicDetailScreen extends StatefulWidget {
  const TopicDetailScreen({super.key, required this.topicId});
  final String topicId;

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  _Filter _filter = _Filter.all;
  bool _byRelevance = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final topic = store.topic(widget.topicId);
        final items = _apply(topic.items);
        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(topic),
              _filterRow(),
              Expanded(
                child: items.isEmpty
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                        child: const EmptyState(
                          glyph: '🔎',
                          title: '조건에 맞는 콘텐츠가 없어요',
                          description: '필터를 바꾸거나 소스를 더 추가해 보세요.',
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          for (final group in _group(items)) ...[
                            _groupHeader(group.key),
                            const SizedBox(height: 10),
                            for (final item in group.value) ...[
                              ContentCard(
                                item: item,
                                onTap: () => context.push('/article/${item.id}?from=topic'),
                              ),
                              const SizedBox(height: 10),
                            ],
                            const SizedBox(height: 10),
                          ],
                          // ponytail: 목업 데이터가 페이지 크기(10)보다 적어 무한 스크롤 대신 종료 문구만 둔다.
                          Center(
                            child: Text('마지막 콘텐츠예요',
                                style: AppText.caption1.c(AppColors.labelAssistive)),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<ContentItem> _apply(List<ContentItem> source) {
    var items = switch (_filter) {
      _Filter.all => [...source],
      _Filter.youtube => source.where((i) => i.kind == ContentKind.youtube).toList(),
      _Filter.article => source.where((i) => i.kind == ContentKind.article).toList(),
    };
    if (_byRelevance) {
      items.sort((a, b) => a.title.length.compareTo(b.title.length));
    } else {
      items.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    }
    return items;
  }

  List<MapEntry<String, List<ContentItem>>> _group(List<ContentItem> items) {
    final map = <String, List<ContentItem>>{};
    for (final i in items) {
      map.putIfAbsent('${i.sentAt.month}월 ${i.sentAt.day}일 발송', () => []).add(i);
    }
    return map.entries.toList();
  }

  Widget _header(Topic topic) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.lineSolid)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 4, 12, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.labelNormal),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.name, style: AppText.headline2.c(AppColors.labelNormal)),
                Text(
                  '소스 ${topic.sources.length} · 알림 ${topic.notify ? "ON" : "OFF"}',
                  style: AppText.caption1.c(AppColors.labelAlt),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/sources?topicId=${topic.id}'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.bgAlt, shape: BoxShape.circle),
              child: const Icon(Icons.folder_open_rounded, size: 18, color: AppColors.labelNeutral),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          AppFilterChip(
            label: '전체',
            selected: _filter == _Filter.all,
            onTap: () => setState(() => _filter = _Filter.all),
          ),
          const SizedBox(width: 6),
          AppFilterChip(
            label: '유튜브',
            selected: _filter == _Filter.youtube,
            onTap: () => setState(() => _filter = _Filter.youtube),
          ),
          const SizedBox(width: 6),
          AppFilterChip(
            label: '아티클',
            selected: _filter == _Filter.article,
            onTap: () => setState(() => _filter = _Filter.article),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _byRelevance = !_byRelevance),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(_byRelevance ? Icons.auto_awesome_rounded : Icons.schedule_rounded,
                    size: 14, color: AppColors.labelAlt),
                const SizedBox(width: 4),
                Text(_byRelevance ? '관련도순' : '최신순', style: AppText.label2.c(AppColors.labelAlt)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupHeader(String label) {
    return Row(
      children: [
        Text(label, style: AppText.label2.w700.c(AppColors.primary)),
        const SizedBox(width: 8),
        const Expanded(child: Divider(height: 1, color: AppColors.lineSolid)),
      ],
    );
  }
}
