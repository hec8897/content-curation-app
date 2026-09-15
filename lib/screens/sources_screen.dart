import 'package:flutter/material.dart';

import '../data/store.dart';
import '../design/app_colors.dart';
import '../design/app_text.dart';
import '../widgets/basics.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key, this.topicId});
  final String? topicId;

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  late int _index = _indexOf(widget.topicId);

  int _indexOf(String? topicId) {
    if (topicId == null) return 0;
    final i = store.topics.indexWhere((t) => t.id == topicId);
    return i < 0 ? 0 : i;
  }

  @override
  void didUpdateWidget(SourcesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.topicId != oldWidget.topicId) _index = _indexOf(widget.topicId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final topics = store.topics;
        final topic = topics[_index.clamp(0, topics.length - 1)];
        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(topics),
              Expanded(
                child: Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                      children: [
                        Text(
                          'RSS 주소나 유튜브 채널을 등록하면 새 콘텐츠를 자동으로 모아요.',
                          style: AppText.caption1.c(AppColors.labelAlt),
                        ),
                        const SizedBox(height: 14),
                        if (topic.sources.isEmpty)
                          EmptyState(
                            glyph: '📡',
                            title: '등록된 소스가 없어요',
                            description: '소스를 추가하면 이 주제의 콘텐츠 수집이 시작돼요.',
                            actionLabel: '소스 추가',
                            onAction: () => _openSearchSheet(topic),
                          )
                        else
                          for (final source in topic.sources)
                            _SourceRow(
                              source: source,
                              onDelete: () => _confirmDelete(topic, source),
                            ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00FFFFFF), AppColors.bg, AppColors.bg],
                            stops: [0, 0.55, 1],
                          ),
                        ),
                        child: PrimaryButton(
                          label: '＋ 소스 추가',
                          onTap: () => _openSearchSheet(topic),
                        ),
                      ),
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

  Widget _header(List<Topic> topics) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.lineSolid)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Text('소스 관리', style: AppText.heading1.c(AppColors.labelNormal)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < topics.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _index = i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.only(right: 18, bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              width: 2.5,
                              color: i == _index ? AppColors.labelNormal : Colors.transparent,
                            ),
                          ),
                        ),
                        child: Text(
                          topics[i].name,
                          style: i == _index
                              ? AppText.label1.w700.c(AppColors.labelNormal)
                              : AppText.label1.w500.c(AppColors.labelAlt),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Topic topic, Source source) async {
    final ok = await showConfirmDialog(
      context,
      title: '소스를 삭제할까요?',
      message: '${source.name}에서 더 이상 콘텐츠를 수집하지 않아요.',
    );
    if (!ok || !mounted) return;
    store.removeSource(topic.id, source.id);
    showToast(context, '소스를 삭제했어요');
  }

  void _openSearchSheet(Topic topic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.dimmer,
      builder: (_) => _SourceSearchSheet(
        existing: topic.sources.map((s) => s.name).toSet(),
        onAdd: (picked) {
          store.addSources(topic.id, picked);
          showToast(context, '소스 ${picked.length}개를 추가했어요');
        },
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.onDelete});
  final Source source;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.fill))),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(12)),
            child: Text(source.glyph, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.name, style: AppText.label1.w600.c(AppColors.labelNormal)),
                const SizedBox(height: 2),
                Text(source.meta, style: AppText.caption1.c(AppColors.labelAlt)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(child: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.labelAlt)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceSearchSheet extends StatefulWidget {
  const _SourceSearchSheet({required this.existing, required this.onAdd});
  final Set<String> existing;
  final ValueChanged<List<Source>> onAdd;

  @override
  State<_SourceSearchSheet> createState() => _SourceSearchSheetState();
}

class _SourceSearchSheetState extends State<_SourceSearchSheet> {
  String _query = '';
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final results = searchCatalog
        .where((s) => !widget.existing.contains(s.name))
        .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return SheetScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('소스 추가', style: AppText.headline2.c(AppColors.labelNormal)),
          const SizedBox(height: 14),
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            style: AppText.body2.c(AppColors.labelNormal),
            decoration: InputDecoration(
              hintText: '이름 또는 RSS 주소 검색',
              hintStyle: AppText.body2.c(AppColors.labelAssistive),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.labelAlt),
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
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text('검색 결과가 없어요', style: AppText.label1.c(AppColors.labelAlt)),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final source in results)
                    GestureDetector(
                      onTap: () => setState(() {
                        _picked.contains(source.id) ? _picked.remove(source.id) : _picked.add(source.id);
                      }),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration:
                                  BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(12)),
                              child: Text(source.glyph, style: const TextStyle(fontSize: 17)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(source.name, style: AppText.label1.w600.c(AppColors.labelNormal)),
                                  Text(source.protocol, style: AppText.caption1.c(AppColors.labelAlt)),
                                ],
                              ),
                            ),
                            Icon(
                              _picked.contains(source.id)
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 22,
                              color: _picked.contains(source.id) ? AppColors.primary : AppColors.lineSolid,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: _picked.isEmpty ? '소스 추가' : '${_picked.length}개 추가하기',
            onTap: _picked.isEmpty
                ? null
                : () {
                    widget.onAdd(searchCatalog.where((s) => _picked.contains(s.id)).toList());
                    Navigator.pop(context);
                  },
          ),
        ],
      ),
    );
  }
}
