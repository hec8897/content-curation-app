import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_text.dart';

class ThumbBox extends StatelessWidget {
  const ThumbBox({super.key, required this.width, required this.height, required this.radius, this.glyph = '📄'});
  final double width;
  final double height;
  final double radius;
  final String glyph;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(radius)),
      child: Text(glyph, style: TextStyle(fontSize: math.min(width, height) * 0.42)),
    );
  }
}

class SourceBadge extends StatelessWidget {
  const SourceBadge(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.lineSolid),
      ),
      child: Text(text, style: AppText.caption2.w600.c(AppColors.labelAlt)),
    );
  }
}

class PillBadge extends StatelessWidget {
  const PillBadge(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: AppText.caption2.c(AppColors.labelAlt)),
    );
  }
}

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.labelNormal : AppColors.bg,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: AppColors.lineSolid),
        ),
        child: Text(
          label,
          style: AppText.label2.w600.c(selected ? Colors.white : AppColors.labelAlt),
        ),
      ),
    );
  }
}

class AppInputChip extends StatelessWidget {
  const AppInputChip({super.key, required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.labelNormal),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.label2.w600.c(AppColors.labelNormal)),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 32,
              height: 44,
              child: Center(child: Icon(Icons.close_rounded, size: 15, color: AppColors.labelAlt)),
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onTap, this.expand = true});
  final String label;
  final VoidCallback? onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final child = Material(
      color: disabled ? AppColors.lineSolid : AppColors.primary,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        highlightColor: AppColors.primaryStrong,
        splashColor: AppColors.primaryStrong,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            label,
            style: AppText.body2.w600.c(disabled ? AppColors.labelAssistive : Colors.white),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class OutlineButton extends StatelessWidget {
  const OutlineButton({super.key, required this.label, required this.onTap, this.leading});
  final String label;
  final VoidCallback onTap;

  /// 라벨 왼쪽 아이콘. 소셜 로그인처럼 로고가 필요한 버튼에 쓴다.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: AppText.label1.w600.c(AppColors.labelNormal));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lineSolid),
        ),
        child: leading == null
            ? text
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [leading!, const SizedBox(width: 8), text],
              ),
      ),
    );
  }
}

class AppTextButton extends StatelessWidget {
  const AppTextButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        child: Text(label, style: AppText.label2.w600.c(AppColors.primary)),
      ),
    );
  }
}

class AppToggle extends StatelessWidget {
  const AppToggle({super.key, required this.value, required this.onChanged, this.dimmed = false});
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 46,
          height: 28,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? AppColors.primary : AppColors.lineSolid,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: cardShadow),
          ),
        ),
      ),
    );
  }
}

class RadioRow extends StatelessWidget {
  const RadioRow({super.key, required this.label, required this.selected, required this.onTap, this.divider = true});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        decoration: divider
            ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.fill)))
            : null,
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.primary : AppColors.lineSolid, width: 1.5),
              ),
              child: selected
                  ? Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))
                  : null,
            ),
            const SizedBox(width: 12),
            Text(label, style: AppText.body2.c(AppColors.labelNormal)),
          ],
        ),
      ),
    );
  }
}

class DashedBox extends StatelessWidget {
  const DashedBox({super.key, required this.child, this.radius = 16, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(radius),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter(this.radius);
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.labelAssistive;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 5, metric.length)), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter oldDelegate) => oldDelegate.radius != radius;
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.glyph,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });
  final String glyph;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DashedBox(
      radius: 18,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Text(glyph, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text(title, style: AppText.headline2.c(AppColors.labelNormal), textAlign: TextAlign.center),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description!, style: AppText.label1.c(AppColors.labelAlt), textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            PrimaryButton(label: actionLabel!, onTap: onAction, expand: false),
          ],
        ],
      ),
    );
  }
}

class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.width, required this.height, this.radius = 8});
  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.55, end: 1.0).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

void showToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.labelNormal.withValues(alpha: 0.92),
      elevation: 0,
      duration: const Duration(milliseconds: 1800),
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 34),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      content: Text(message, style: AppText.label2.w600.c(Colors.white), textAlign: TextAlign.center),
    ),
  );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '삭제',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.dimmer,
    builder: (context) => Center(
      child: Container(
        width: 272,
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  Text(title, style: AppText.headline2.c(AppColors.labelNormal), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(message, style: AppText.label2.c(AppColors.labelAlt), textAlign: TextAlign.center),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(child: OutlineButton(label: '취소', onTap: () => Navigator.pop(context, false))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.statusNegative,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(confirmLabel, style: AppText.label1.w600.c(Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

class SheetScaffold extends StatelessWidget {
  const SheetScaffold({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: sheetShadow,
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(color: AppColors.lineSolid, borderRadius: BorderRadius.circular(999)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
            child: child,
          ),
        ],
      ),
    );
  }
}
