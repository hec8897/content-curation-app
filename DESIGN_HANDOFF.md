# 콘텐츠 큐레이션 앱 — Flutter 디자인 핸드오프

Wanted Montage Foundations(light) 토큰 기반 · 7개 화면.
시각적 기준 문서: `docs/design-handoff.html` (오프라인 단독 실행)

---

## 1. 색상 토큰

```dart
// lib/design/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  static const primary        = Color(0xFF0066FF);
  static const primaryStrong  = Color(0xFF005EEB); // pressed
  static const primaryTint    = Color(0xFFEAF2FE);
  static const primaryLine    = Color(0x470066FF); // 28%
  static const labelNormal    = Color(0xFF171719);
  static const labelNeutral   = Color(0xE02E2F33); // 88%
  static const labelAlt       = Color(0x9C37383C); // 61%
  static const labelAssistive = Color(0x4737383C); // 28%
  static const bg             = Color(0xFFFFFFFF);
  static const bgAlt          = Color(0xFFF7F7F8);
  static const lineSolid      = Color(0xFFE1E2E4);
  static const fill           = Color(0xFFF4F4F5);
  static const statusNegative = Color(0xFFFF4242);
  static const dimmer         = Color(0x85171719); // 52%
}
```

이 표 밖의 색은 사용하지 않습니다.

## 2. 타이포그래피

폰트 Pretendard (400/500/600/700). letterSpacing은 Montage em 값을 px로 환산.

| 토큰 | size | line | letterSpacing | weight |
| --- | --- | --- | --- | --- |
| title3 | 24 | 32 | -0.55 | 700 |
| heading1 | 22 | 30 | -0.43 | 700 |
| headline2 | 17 | 26 | 0 | 600 |
| body1 | 16 | 24 | +0.09 | 400/600 |
| body2 | 15 | 22 | +0.14 | 400/600 |
| label1 | 14 | 20 | +0.20 | 500/600 |
| label2 | 13 | 18 | +0.25 | 500/600 |
| caption1 | 12 | 16 | +0.30 | 400/600 |
| caption2 | 11 | 14 | +0.34 | 500/600 |

```dart
// lib/design/app_text.dart
class AppText {
  static const _f = 'Pretendard';
  static const title3    = TextStyle(fontFamily:_f, fontSize:24, height:32/24, letterSpacing:-0.55, fontWeight:FontWeight.w700);
  static const heading1  = TextStyle(fontFamily:_f, fontSize:22, height:30/22, letterSpacing:-0.43, fontWeight:FontWeight.w700);
  static const headline2 = TextStyle(fontFamily:_f, fontSize:17, height:26/17, letterSpacing:0,     fontWeight:FontWeight.w600);
  static const body1     = TextStyle(fontFamily:_f, fontSize:16, height:24/16, letterSpacing:0.09);
  static const body2     = TextStyle(fontFamily:_f, fontSize:15, height:22/15, letterSpacing:0.14);
  static const label1    = TextStyle(fontFamily:_f, fontSize:14, height:20/14, letterSpacing:0.20, fontWeight:FontWeight.w500);
  static const label2    = TextStyle(fontFamily:_f, fontSize:13, height:18/13, letterSpacing:0.25, fontWeight:FontWeight.w500);
  static const caption1  = TextStyle(fontFamily:_f, fontSize:12, height:16/12, letterSpacing:0.30);
  static const caption2  = TextStyle(fontFamily:_f, fontSize:11, height:14/11, letterSpacing:0.34, fontWeight:FontWeight.w500);
}
```

## 3. 스페이싱 · 라운드 · 엘리베이션

- Spacing: 2·4·6·8·10·12·14·16·20·24·32·40 / 화면 좌우 16 · 섹션 간격 20 · 카드 내부 12~16
- Radius: 썸네일 8~12 · 리스트 아이템 12 · 카드/버튼 14~16 · 바텀시트 상단 24 · 칩·토글·아바타 999

```dart
const cardShadow  = [BoxShadow(color: Color(0x1A171717), offset: Offset(0,1),   blurRadius: 2, spreadRadius: -1)];
const sheetShadow = [BoxShadow(color: Color(0x29171717), offset: Offset(0,-15), blurRadius: 75)];
```

## 4. 공통 컴포넌트

**ContentCard** — variant 2종.
`compact`(다이제스트·히스토리): 썸네일 56×44 r8, 제목 label1/600 1줄 ellipsis, 서브 caption1 labelAlt, 우측 chevron, 세로 패딩 11, 하단 divider `fill`.
`list`(주제 상세): 카드 r16 + lineSolid + cardShadow, 패딩 12, 썸네일 96×74 r12, 배지 → 제목(label1/600 최대 2줄) → 메타 caption1. 탭 영역은 카드 전체, ripple primary 8%.

```dart
ContentCard({required ContentItem item, ContentCardVariant variant = ContentCardVariant.list, VoidCallback? onTap})
```

**SourceBadge** 높이 20, 패딩 h8, r999, border lineSolid, caption2/600, 텍스트 labelAlt.
**FilterChip**(단일 선택) 높이 32, 패딩 h13, r999 — 선택: bg labelNormal/white, 미선택: white + lineSolid + labelAlt.
**InputChip**(주제 키워드) 높이 32, r999, border labelNormal, 우측 ✕ 히트영역 44×44.

**PrimaryButton** 높이 52(패딩 15), r14~16, body2/600, bg primary·텍스트 white, pressed primaryStrong, disabled bg lineSolid + labelAssistive.
기본 CTA는 모두 Primary(파란색): 시작하기 · 소스 추가 · 원문/유튜브 보기 · 선택 완료 · 주제 등록하기.
**TextButton** label2/600 primary (더보기 · 연동하기 · 모두 보기).

**AppToggle** track 46×28 r999, knob 22 white+shadow, on primary / off lineSolid, 180ms easeOut. 미연동 채널은 opacity .45 + 탭 시 "먼저 연동해 주세요" 토스트.
**RadioRow** 원 20 border 1.5(선택 primary), dot 10, 행 높이 48, 하단 divider.

**BottomSheet** `showModalBottomSheet(isScrollControlled: true)`, 상단 r24, grabber 42×4, 패딩 12/18/26, 결과 리스트 최대 260 스크롤, 280ms cubic(.32,.72,0,1), 배경 dimmer.
**ConfirmDialog** 폭 272, r20, 제목 headline2, 본문 label2 labelAlt, 버튼 2분할(취소 outline / 삭제 statusNegative fill).
**Toast** SnackBar floating, bg #171719 92%, r999, 패딩 10/18, label2/600 white, 1.8s, 하단 여백 34(탭바 위).

**EmptyState** dashed 1px labelAssistive, r16~20, 패딩 28/20, 아이콘 32 → 타이틀 headline2 → 설명 label1 labelAlt → (선택) Primary 버튼.
**Skeleton** fill 블록, opacity .55→1→.55 1.2s 반복. 다이제스트는 헤더바 1 + 행 2개.

## 5. 내비게이션

StatefulShellRoute 기반 4탭. 탭바 높이 62 + safe area, bg white, top border fill, 아이콘 19 + caption2. 활성 labelNormal/600, 비활성 labelAlt/500.

```
/onboarding                 // 최초 1회, 탭바 없음 (완료 여부 로컬 저장)
/                           // 홈 (다이제스트 + 주제 리스트)
  /topic/:topicId           // 주제 상세 — 탭바 유지
  /article/:articleId       // 아티클 상세 — 탭바 숨김
/sources?topicId=           // 소스 관리 (진입 시 마지막 주제 선택)
/history                    // 알림 히스토리
/settings                   // 알림 설정
```

- 아티클 상세는 진입 컨텍스트(`digest` / `topic` / `history`)를 넘겨 "9월 14일 다이제스트 · 1 / 3" 표기와 "다음 콘텐츠" 이어보기를 구성합니다. 컨텍스트가 history면 탭 하이라이트는 알림 탭.
- 탭 전환 시 해당 탭 스택은 초기화.

## 6. 화면별 스펙 · 상태

### 홈
AppBar 없이 타이틀 heading1 + ⚙ 아이콘 버튼(36 r999, bg bgAlt). 다이제스트 카드 r20, border primary 1.5, 헤더 bar bg primary(패딩 14/18, white) + compact 카드 3개 + "n건 모두 보기" TextButton. 이어서 주제 섹션(헤더 label1/700 + "다음 발송까지 N시간" caption1) · 주제 행 카드 · "＋ 주제 추가" dashed.
상태 — loading: 다이제스트 스켈레톤 + 주제 행 2개 / 주제 0개: EmptyState("아직 주제가 없어요" + 주제 등록하기) / 소스 0개 주제 행: 라벨·메타 labelAssistive, 메타 "소스 0 — 소스를 추가해 주세요" / 알림 OFF 주제: 우측 "알림 OFF" 배지(fill r999 caption2).

### 주제 상세
sticky 헤더(bg white, 하단 border lineSolid): ← + 주제명 headline2 / 서브 "소스 N · 알림 ON" caption1 + 🗂 버튼(→ 소스 관리, 해당 주제 선택). 필터 행: FilterChip 전체/유튜브/아티클 + 우측 정렬 토글(최신순 ↔ 관련도순). 본문은 발송일 그룹 헤더(label2/700 primary + 1px 라인) + list 카드. 무한 스크롤 page size 10.
상태 — 결과 0건: "조건에 맞는 콘텐츠가 없어요" dashed / 리스트 끝: "마지막 콘텐츠예요" caption1 labelAssistive.

### 아티클 상세
헤더: ← / 중앙 컨텍스트 caption1 / 공유 ↗. 썸네일 16:9 r16 fill → 제목 heading1(2~3줄) → 메타 label2 labelAlt("출처 · 유튜브 · 2026.09.12", 0패딩 필수) → AI 요약 카드(bg primaryTint, border primaryLine, r18, 라벨 label2/700 primary, 본문 body2 height 1.65) → Primary 버튼(url_launcher external) → 다음 콘텐츠 행.
상태 — 로딩: "✨ AI 요약 생성 중…" + 스켈레톤 3줄 / 실패: dashed 카드 + 재시도 outline 버튼.

### 소스 관리
sticky 헤더 + 주제 TabBar(가로 스크롤, 활성 하단 인디케이터 2.5px labelNormal, label1 700/500). 안내 caption1 → 소스 아이템(파비콘 38 r12, 이름 label1/600, 메타 "RSS · 최근 수집 3시간 전", 삭제 아이콘 히트 44) → 하단 고정 Primary "＋ 소스 추가"(위쪽 흰색 그라디언트 페이드).
플로우 — 삭제 → ConfirmDialog → 토스트 "소스를 삭제했어요" / 추가 → BottomSheet 검색 → 다중 선택 → "N개 추가하기" → 토스트.
직접 추가 — 검색어가 주소 형태면 결과 맨 위에 입력 주소 행(이름=호스트, 메타 "RSS · 직접 추가" / youtube.com·youtu.be는 "YouTube · 직접 추가")이 생기고 추천 소스와 같이 선택한다. 추가 후 메타는 "수집 대기 중".
상태 — 소스 0개: EmptyState / 검색 0건: "검색 결과가 없어요".

### 알림 설정
상단 요약 배너(bg primaryTint, r16, body2): "지금 설정: 매일 오전 8:00, 이메일 채널로 주제 2개의 새 콘텐츠를 보내드려요" — 값 변경 시 즉시 재생성. 채널 카드(아이콘 36 r11 fill + 이름 + 연동 배지 + 토글, 미연동은 서브 안내문 + "연동하기 ›"), 발송 주기 RadioRow 3개 + 발송 시간 행(time picker), 주제별 토글 리스트.
규칙 — 저장 버튼 없음: 변경 즉시 저장 + "저장됨" 토스트. 연동 완료 시 배지 연동됨 + 서브를 연결 계정/채널로 갱신하고 토글 자동 ON. 모든 채널 OFF면 배너를 경고 문구로 대체.

### 알림 히스토리 · 온보딩
히스토리: 발송 단위 카드(r18, 최신 발송만 border primary) — 날짜 label1/700 + "✉ 이메일 · 3건" caption1 + compact 카드 리스트. 없으면 "아직 발송된 알림이 없어요".
온보딩: 진행 인디케이터(3점) + 건너뛰기 → 타이틀 title3 → 키워드 입력(TextField r12 border lineSolid, 엔터/＋ 추가, 중복은 토스트) + InputChip 리스트 → 소스 검색·체크 리스트 + "나중에 소스 관리에서도 추가할 수 있어요" → 하단 Primary "시작하기"(주제 0개면 disabled + 보조 문구).

## 7. 전달 노트

- 색·타이포 값은 Montage(wanteddev/montage-web) light 토큰에서 가져왔습니다. 컴포넌트는 스펙대로 직접 구현한 것이며 Montage 위젯이 아닙니다.
- 터치 타깃 최소 44×44, 본문 대비 4.5:1 유지.
- 아이콘은 현재 이모지 플레이스홀더 — 실제 아이콘셋(24px 라인) 전달 필요.
- 인터랙션 타이밍: 화면 전환 260ms, 토글 180ms, 바텀시트 280ms, 토스트 1.8s.
