import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/store.dart';
import '../design/app_colors.dart';
import '../design/app_text.dart';
import '../widgets/basics.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text('알림 설정', style: AppText.heading1.c(AppColors.labelNormal)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: store.activeChannels.isEmpty ? AppColors.fill : AppColors.primaryTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                store.summaryBanner,
                style: AppText.body2.c(
                  store.activeChannels.isEmpty ? AppColors.statusNegative : AppColors.labelNeutral,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('알림 채널'),
            for (final channel in store.channels) ...[
              _ChannelCard(channel: channel),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            _sectionTitle('발송 주기'),
            RadioRow(
              label: '매일',
              selected: store.cycle == SendCycle.daily,
              onTap: () => _set(context, () => store.setCycle(SendCycle.daily)),
            ),
            RadioRow(
              label: '평일만',
              selected: store.cycle == SendCycle.weekdays,
              onTap: () => _set(context, () => store.setCycle(SendCycle.weekdays)),
            ),
            RadioRow(
              label: '주 1회',
              selected: store.cycle == SendCycle.weekly,
              onTap: () => _set(context, () => store.setCycle(SendCycle.weekly)),
            ),
            GestureDetector(
              onTap: () => _pickTime(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 52,
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.fill))),
                child: Row(
                  children: [
                    Expanded(child: Text('발송 시간', style: AppText.body2.c(AppColors.labelNormal))),
                    Text(store.timeLabel, style: AppText.body2.c(AppColors.labelAlt)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.labelAssistive),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('주제별 알림'),
            for (final topic in store.topics)
              Container(
                height: 56,
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.fill))),
                child: Row(
                  children: [
                    Expanded(child: Text(topic.name, style: AppText.body2.c(AppColors.labelNormal))),
                    AppToggle(
                      value: topic.notify,
                      onChanged: (v) => _set(context, () => store.toggleTopicNotify(topic.id, v)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            Center(
              child: AppTextButton(
                label: '로그아웃',
                onTap: () async {
                  final ok = await showConfirmDialog(
                    context,
                    title: '로그아웃할까요?',
                    message: '다시 로그인하면 설정은 그대로 남아 있어요.',
                    confirmLabel: '로그아웃',
                  );
                  if (ok) await auth.signOut();
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: AppText.label1.w700.c(AppColors.labelNormal)),
      );

  // 저장 버튼 없음 — 변경 즉시 저장 + 토스트
  void _set(BuildContext context, VoidCallback action) {
    action();
    showToast(context, '저장됨');
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: store.sendHour, minute: store.sendMinute),
    );
    if (picked == null || !context.mounted) return;
    _set(context, () => store.setTime(picked.hour, picked.minute));
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lineSolid),
        boxShadow: cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(11)),
            child: Text(channel.glyph, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(channel.name, style: AppText.label1.w600.c(AppColors.labelNormal)),
                    const SizedBox(width: 6),
                    PillBadge(channel.linked ? '연동됨' : '미연동'),
                  ],
                ),
                const SizedBox(height: 2),
                if (channel.linked)
                  Text(channel.account ?? '연결됨', style: AppText.caption1.c(AppColors.labelAlt))
                else
                  Row(
                    children: [
                      Text('계정을 연결하면 알림을 받을 수 있어요', style: AppText.caption1.c(AppColors.labelAlt)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          store.linkChannel(channel.id);
                          showToast(context, '${channel.name} 연동을 완료했어요');
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Text('연동하기 ›', style: AppText.label2.w600.c(AppColors.primary)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppToggle(
            value: channel.on,
            dimmed: !channel.linked,
            onChanged: (v) {
              if (!channel.linked) {
                showToast(context, '먼저 연동해 주세요');
                return;
              }
              store.toggleChannel(channel.id, v);
              showToast(context, '저장됨');
            },
          ),
        ],
      ),
    );
  }
}
