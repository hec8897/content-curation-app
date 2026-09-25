# ROADMAP

2026-09-25 기준. 의존 순서대로 나열했다 — 위 단계가 아래 단계의 전제다.

## 현재 완성도

| 영역 | 상태 |
|---|---|
| UI 목업 (7화면 + 로그인) | ✅ 완료. 오버플로 13px·폰트 미번들·이모지 썸네일 남음 |
| 백엔드 인증 (이메일·Google·JWT) | ✅ 완료, Flutter에서도 동작 |
| 백엔드 사용자 데이터 CRUD (`/bootstrap`, topics/sources/channels/settings) | ✅ 라우트 완비 |
| Flutter ↔ 데이터 API 연결 | 🟡 구현 완료, QA 진행 중 |
| 콘텐츠 수집기 (RSS·YouTube) | ❌ 없음. `store.dart` 목업 상수 |
| AI 요약 | ❌ `Future.delayed` 흉내 |
| 실제 발송 (스케줄·채널) | ❌ 없음 |
| 마이그레이션 (Alembic) | ❌ 의도적 보류 |

## 단계

### 1. 데이터 연결
- [x] 앱 진입 시 `GET /bootstrap`으로 주제·소스·채널·설정 로드
- [x] `AppStore` 메서드 비동기화 → 대응 라우트 호출 (`completeOnboarding`, `addSources`, `removeSource`, `addTopic`, `toggleTopicNotify`, `toggleChannel`, `linkChannel`, `setCycle`, `setTime`)
- [x] 온보딩 완료 여부를 기기 Keychain에 계정별 저장 (서버 판정 대신 결정)
- [x] 콘텐츠 목업은 `topics.slug`로 클라이언트에서 붙임 (수집기 전까지의 접합점)
- [ ] QA — 디자인 어긋남·사용성 점검 (소스 삭제·주제 추가·토글·연동·발송 설정은 앱에서 미확인)
- [ ] 홈 900ms 가짜 로딩 제거

### 2. UI 잔여 버그 (언제든 끼워넣기 가능)
- [ ] 알림 설정 미연동 채널 행 가로 오버플로 (~13px)
- [ ] Pretendard 번들 (`assets/fonts/` + `pubspec.yaml`)
- [ ] 주제 상세 무한 스크롤

### 3. 수집기
- [ ] `items` 테이블 + RSS 수집
- [ ] Alembic 도입 (지울 수 없는 데이터가 생기는 시점)
- [ ] YouTube 수집 (API 키 필요)
- [ ] 클라이언트 목업 접합점 제거, 썸네일 실제 이미지로 `ThumbBox` 교체

### 4. AI 요약
- [ ] 수집 아이템 요약 생성·캐시
- [ ] 실패 상태를 실제 에러로 대체 (현재 `a3` 의도적 실패)

### 5. 발송
- [ ] 스케줄러 (발송 주기·시각 설정 반영)
- [ ] 채널 1개(이메일 또는 푸시)부터 연동

### 6. 배포
- [ ] `DATABASE_URL` / `JWT_SECRET` 환경변수 주입
- [ ] 호스팅 선택
