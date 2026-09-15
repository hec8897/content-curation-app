import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/store.dart';
import '../design/app_colors.dart';
import '../design/app_text.dart';
import '../widgets/basics.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final _keywords = <String>[];
  final _picked = <String>{};
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == 2;
    final blocked = last && _keywords.isEmpty;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Container(
                      width: i == _step ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _step
                            ? AppColors.primary
                            : AppColors.lineSolid,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  const Spacer(),
                  AppTextButton(label: '건너뛰기', onTap: _finish),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                children: switch (_step) {
                  0 => _intro(),
                  1 => _keywordStep(),
                  _ => _sourceStep(),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  if (blocked) ...[
                    Text(
                      '키워드를 1개 이상 등록해 주세요',
                      style: AppText.caption1.c(AppColors.labelAlt),
                    ),
                    const SizedBox(height: 8),
                  ],
                  PrimaryButton(
                    label: last ? '시작하기' : '다음',
                    onTap: blocked
                        ? null
                        : (last ? _finish : () => setState(() => _step++)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _intro() => [
    const Text('📮', style: TextStyle(fontSize: 44)),
    const SizedBox(height: 16),
    Text(
      '관심 13주제만 골라\n매일 아침 모아 보내드려요',
      style: AppText.title3.c(AppColors.labelNormal),
    ),
    const SizedBox(height: 10),
    Text(
      '키워드와 소스를 등록하면 새 아티클과 영상을 AI 요약과 함께 정리해 알려드려요.',
      style: AppText.body2.c(AppColors.labelAlt),
    ),
  ];

  List<Widget> _keywordStep() => [
    Text('어떤 주제가 궁금하세요?', style: AppText.title3.c(AppColors.labelNormal)),
    const SizedBox(height: 10),
    Text(
      '키워드를 입력하고 엔터를 누르면 주제로 등록돼요.',
      style: AppText.body2.c(AppColors.labelAlt),
    ),
    const SizedBox(height: 20),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            onSubmitted: (_) => _addKeyword(),
            style: AppText.body2.c(AppColors.labelNormal),
            decoration: InputDecoration(
              hintText: '예: LLM 에이전트',
              hintStyle: AppText.body2.c(AppColors.labelAssistive),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
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
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _addKeyword,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.bgAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_rounded,
              size: 22,
              color: AppColors.labelNormal,
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 16),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final keyword in _keywords)
          AppInputChip(
            label: keyword,
            onRemove: () => setState(() => _keywords.remove(keyword)),
          ),
      ],
    ),
  ];

  List<Widget> _sourceStep() => [
    Text('콘텐츠를 가져올 소스를 골라주세요', style: AppText.title3.c(AppColors.labelNormal)),
    const SizedBox(height: 10),
    Text('나중에 소스 관리에서도 추가할 수 있어요.', style: AppText.body2.c(AppColors.labelAlt)),
    const SizedBox(height: 16),
    for (final source in searchCatalog)
      GestureDetector(
        onTap: () => setState(() {
          _picked.contains(source.id)
              ? _picked.remove(source.id)
              : _picked.add(source.id);
        }),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.fill)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(source.glyph, style: const TextStyle(fontSize: 17)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      style: AppText.label1.w600.c(AppColors.labelNormal),
                    ),
                    Text(
                      source.protocol,
                      style: AppText.caption1.c(AppColors.labelAlt),
                    ),
                  ],
                ),
              ),
              Icon(
                _picked.contains(source.id)
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: _picked.contains(source.id)
                    ? AppColors.primary
                    : AppColors.lineSolid,
              ),
            ],
          ),
        ),
      ),
  ];

  void _addKeyword() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    if (_keywords.contains(value)) {
      showToast(context, '이미 등록한 키워드예요');
      return;
    }
    setState(() {
      _keywords.add(value);
      _controller.clear();
    });
  }

  void _finish() {
    store.completeOnboarding(
      _keywords,
      searchCatalog.where((s) => _picked.contains(s.id)).toList(),
    );
    context.go('/');
  }
}
