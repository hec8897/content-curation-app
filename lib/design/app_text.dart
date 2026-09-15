import 'package:flutter/material.dart';

// ponytail: Pretendard 폰트 파일 미번들 — iOS/Android 시스템 한글 폰트로 폴백한다.
// 실제 빌드 시 assets/fonts/Pretendard-*.otf 추가 + pubspec fonts 선언만 하면 된다.
class AppText {
  static const _f = 'Pretendard';

  static const title3 = TextStyle(
      fontFamily: _f, fontSize: 24, height: 32 / 24, letterSpacing: -0.55, fontWeight: FontWeight.w700);
  static const heading1 = TextStyle(
      fontFamily: _f, fontSize: 22, height: 30 / 22, letterSpacing: -0.43, fontWeight: FontWeight.w700);
  static const headline2 = TextStyle(
      fontFamily: _f, fontSize: 17, height: 26 / 17, letterSpacing: 0, fontWeight: FontWeight.w600);
  static const body1 = TextStyle(fontFamily: _f, fontSize: 16, height: 24 / 16, letterSpacing: 0.09);
  static const body2 = TextStyle(fontFamily: _f, fontSize: 15, height: 22 / 15, letterSpacing: 0.14);
  static const label1 = TextStyle(
      fontFamily: _f, fontSize: 14, height: 20 / 14, letterSpacing: 0.20, fontWeight: FontWeight.w500);
  static const label2 = TextStyle(
      fontFamily: _f, fontSize: 13, height: 18 / 13, letterSpacing: 0.25, fontWeight: FontWeight.w500);
  static const caption1 = TextStyle(fontFamily: _f, fontSize: 12, height: 16 / 12, letterSpacing: 0.30);
  static const caption2 = TextStyle(
      fontFamily: _f, fontSize: 11, height: 14 / 11, letterSpacing: 0.34, fontWeight: FontWeight.w500);
}

extension TextStyleWeight on TextStyle {
  TextStyle get w400 => copyWith(fontWeight: FontWeight.w400);
  TextStyle get w500 => copyWith(fontWeight: FontWeight.w500);
  TextStyle get w600 => copyWith(fontWeight: FontWeight.w600);
  TextStyle get w700 => copyWith(fontWeight: FontWeight.w700);
  TextStyle c(Color color) => copyWith(color: color);
}
