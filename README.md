# 큐레이터 (content-curation-app)

관심 키워드에 맞는 아티클·영상을 모아 AI 요약과 함께 정기 발송하는 콘텐츠 큐레이션 앱.
UI 목업으로 시작해 기능을 하나씩 붙이는 중이다.

- **`backend/`** — FastAPI + Postgres. 인증과 사용자 설정(주제·소스·채널·발송 스케줄)이 실제로 저장된다.
- **`lib/`** — Flutter 앱. 아직 인메모리 스토어를 쓴다. 백엔드 연결은 미완료.
- 콘텐츠 수집·AI 요약·실제 발송은 아직 없다. 화면에 보이는 아티클은 목업 데이터다.

## 실행

```bash
flutter pub get
xcrun simctl boot "iPhone 17"   # iOS 시뮬레이터 부팅 (또는 open -a DeviceHub)
flutter run -d "iPhone 17"
```

백엔드는 별도로 띄운다. DB 접속 정보와 주의사항은 `CLAUDE.md`의 백엔드 절에 있다.

```bash
cd backend
docker compose up -d                              # Postgres
uv run uvicorn app.main:app --reload --port 8000  # API (http://localhost:8000/docs)
```

`flutter analyze`는 무경고 상태를 유지한다.

Xcode 27부터 **Simulator.app이 사라졌다.** `open -a Simulator`는 더 이상 동작하지 않으니
위처럼 `simctl boot`으로 띄우거나 새로 들어온 `DeviceHub.app`을 쓴다.
`flutter doctor`가 "iOS 27.0 Simulator not installed"를 경고하지만, 남아 있는 iOS 26.5 런타임으로
빌드·실행 모두 정상이다.

## 디자인 기준

| 파일 | 용도 |
| --- | --- |
| `DESIGN_HANDOFF.md` | 토큰·컴포넌트·화면 스펙 (구현의 단일 기준) |
| `design-handoff.html` | 시각적 기준 문서 (브라우저에서 단독 실행) |
| `design-prototype.html` | 최초 디자인 프로토타입 (React 번들 출력, 4MB) |

색·타이포는 Wanted Montage Foundations(light) 토큰에서 가져왔다.
`DESIGN_HANDOFF.md`의 표 밖에 있는 색·스타일은 쓰지 않는다 — 새 값이 필요하면 핸드오프 문서를 먼저 고친다.

## 구조

```
lib/
  app.dart                 라우터(StatefulShellRoute 4탭) + 탭바
  design/app_colors.dart   색 토큰 + 섀도우
  design/app_text.dart     타이포 토큰 + weight/color 확장
  data/store.dart          모델 + 목업 데이터 + ChangeNotifier 스토어
  widgets/basics.dart      버튼·칩·토글·라디오·빈 상태·스켈레톤·토스트·다이얼로그·바텀시트
  widgets/content_card.dart  ContentCard (compact / list)
  screens/                 7개 화면
```

라우트

```
/onboarding                 최초 1회, 탭바 없음
/                           홈 (다이제스트 + 주제 리스트)
  /topic/:topicId           주제 상세 — 탭바 유지
/article/:articleId?from=   아티클 상세 — 탭바 숨김 (from: digest|topic|history)
/sources?topicId=           소스 관리
/history                    알림 히스토리
/settings                   알림 설정
```

상태관리는 `store` 전역 인스턴스 + `ListenableBuilder`뿐이다. 목업 범위에서 패키지를 넣을 이유가 없어 넣지 않았다.

## 알려진 제약

- **Flutter가 백엔드에 연결되지 않았다** — API는 준비됐지만 앱은 여전히 인메모리 스토어를 쓴다.
  앱을 닫으면 사용자가 만든 주제·설정이 사라진다.
- **마이그레이션 도구가 없다** — 백엔드가 시작할 때 테이블을 생성하므로, 모델을 고쳤으면
  `cd backend && docker compose down -v`로 DB를 초기화해야 반영된다.
- **Pretendard 미번들** — 시스템 한글 폰트로 폴백한다. `assets/fonts/Pretendard-*.otf` 추가 후 `pubspec.yaml`에 `fonts:` 선언만 하면 적용된다.
- **썸네일이 이모지 플레이스홀더** — 실제 이미지가 들어오면 `ThumbBox` 하나만 교체하면 된다. 아이콘도 핸드오프 노트대로 24px 라인 아이콘셋 전달 대기 중.
- **레이아웃 오버플로** — 알림 설정 화면의 미연동 채널 행에서 안내문 + "연동하기 ›"가 가로로 넘친다. 수정 예정.
- **주제 상세 무한 스크롤 미구현** — 목업 데이터가 페이지 크기(10)보다 적어 종료 문구만 둔 상태.
- **온보딩 완료 여부가 앱 재시작 시 초기화** — 로컬 저장을 붙이지 않았다.

코드에 `ponytail:` 주석이 붙은 곳은 의도적으로 단순화한 지점이고, 주석에 확장 방법이 적혀 있다.
