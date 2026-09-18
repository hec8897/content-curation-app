# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Flutter app ("큐레이터") for Korean content curation: keyword-based topics collect articles/videos
from RSS and YouTube sources, and get delivered on a schedule with AI summaries. Copy is Korean throughout.

Started as a pure UI mockup and is being wired up one piece at a time. What exists now:

- **`backend/`** — FastAPI + Postgres. 인증과 사용자 소유 데이터(주제·소스·채널·발송 설정)가 실제로 저장된다.
- **`lib/`** — Flutter 앱. 아직 `AppStore`의 인메모리 데이터를 쓴다. 백엔드 연결은 미완료.
- **콘텐츠 아이템** — 수집기가 없어 여전히 `store.dart`의 목업 상수다. AI 요약도 `Future.delayed` 흉내.

```bash
xcrun simctl boot "iPhone 17"   # Xcode 27에는 Simulator.app이 없다 — open -a Simulator는 실패한다
flutter run -d "iPhone 17"
flutter analyze                 # 무경고 상태를 유지한다
```

`flutter doctor`의 "iOS 27.0 Simulator not installed" 경고는 무시한다. iOS 26.5 런타임으로 빌드·실행 모두 된다.

## 백엔드 (`backend/`)

FastAPI + Postgres. Python 환경은 `uv`가 관리하므로 `activate`는 필요 없다 — 전부 `uv run`으로 실행한다.

```bash
cd backend
docker compose up -d                              # Postgres. 한 번 띄우면 계속 돌아간다
uv run uvicorn app.main:app --reload --port 8000  # API 서버
curl localhost:8000/health                        # {"status":"ok"}
open http://localhost:8000/docs                   # 자동 생성 문서에서 바로 호출 가능
```

로컬 개발용 DB 접속 정보다. **로컬 Docker 컨테이너 전용이고 배포되지 않으므로 여기 적어둔다.**
실제 배포가 생기면 `DATABASE_URL` / `JWT_SECRET`을 환경변수로 주입하고 이 값들은 쓰지 않는다.

| | 값 |
|---|---|
| Host / Port | `localhost` / `5432` |
| Database | `curator` |
| User / Password | `curator` / `curator` |
| `DATABASE_URL` 기본값 | `postgresql+psycopg://curator:curator@localhost:5432/curator` |
| `JWT_SECRET` 기본값 | `dev-only-secret-do-not-deploy` |

DBeaver가 이미 설치돼 있다 — 위 값으로 PostgreSQL 연결을 만들면 된다. 터미널이 편하면
`docker compose exec db psql -U curator -d curator`.

```bash
docker compose down      # DB 정지, 데이터 유지
docker compose down -v   # DB 정지 + 데이터 삭제. 스키마를 바꿨으면 이걸 쓴다
```

**마이그레이션 도구가 없다.** 시작 시 `Base.metadata.create_all()`로 테이블을 만들기 때문에
기존 테이블의 컬럼 변경은 반영되지 않는다. 모델을 고쳤으면 `down -v`로 초기화하는 것이 정상 절차다.
지울 수 없는 데이터가 생기는 시점에 Alembic을 도입한다.

라우트는 `app/main.py` 한 파일에 있고, Flutter `AppStore`의 상태 변경 메서드와 1:1로 대응한다.
`GET /bootstrap`이 주제·소스·채널·설정을 한 번에 돌려주므로 앱 진입 시 왕복이 한 번이면 된다.

모든 변경 라우트는 소유권을 검사한다 — 남의 주제·소스는 404다. 이 검사를 우회하는 라우트를 새로 만들지 말 것.

## Design is a contract, not a suggestion

`DESIGN_HANDOFF.md` is the single source of truth for colors, typography, spacing, and per-screen
behavior. Every value in `lib/design/` came from it verbatim.

- **Never introduce a color or text style outside `AppColors` / `AppText`.** If a new value seems
  necessary, that is a signal to amend `DESIGN_HANDOFF.md` first, then mirror it into the token files.
- `design-handoff.html` is the visual reference — open it in a browser to compare against a screen.

## Structure

```
lib/
  app.dart                   GoRouter + StatefulShellRoute 4탭 + 탭바
  design/app_colors.dart     색 토큰, cardShadow / sheetShadow
  design/app_text.dart       타이포 토큰 + .w600 / .c(color) 확장
  data/store.dart            모델 + 목업 데이터 + AppStore(ChangeNotifier)
  widgets/basics.dart        ThumbBox, 배지, 칩, 버튼, 토글, RadioRow, EmptyState,
                             Skeleton, DashedBox, showToast, showConfirmDialog, SheetScaffold
  widgets/content_card.dart  ContentCard (compact / list)
  screens/                   7개 화면

backend/
  docker-compose.yml         postgres:17, 볼륨 pgdata
  app/db.py                  엔진 + 세션 + Base (동기 SQLAlchemy)
  app/models.py              users / topics / sources / channels / delivery_settings
  app/auth.py                bcrypt + JWT + current_user 의존성
  app/main.py                Pydantic 스키마 + 전체 라우트 + 가입 시드
```

Routes — 아티클 상세만 셸 밖에 있어 탭바가 숨는다.

```
/onboarding
/                           → /topic/:topicId (탭바 유지)
/article/:articleId?from=digest|topic|history
/sources?topicId=
/history
/settings
```

`from` 쿼리는 아티클 상세의 "9월 14일 다이제스트 · 1 / 3" 표기와 "다음 콘텐츠" 목록을 결정한다
(`store.siblings`). 탭 전환 시 해당 탭 스택은 `goBranch(initialLocation: true)`로 초기화한다.

## Conventions that matter

- **상태관리 패키지 없음.** 전역 `store` 인스턴스 + `ListenableBuilder`가 전부다. 목업 범위에서
  Riverpod/Bloc을 새로 들이지 말고, 상태를 바꾸는 코드는 `AppStore`의 메서드로 넣어 `notifyListeners()`를 타게 한다.
- **`ThumbBox`는 이름 때문에 그렇게 불린다.** Material에 이미 `Thumb`(slider)가 있어 `ambiguous_import`가 난다.
  마찬가지로 칩은 `AppFilterChip` / `AppInputChip` — Material 동명 위젯과 충돌을 피한 이름이다.
- **비동기는 `Future.delayed`로 흉내낸다.** 홈 초기 로딩 900ms, 아티클 AI 요약 1100ms.
  아티클 `a3`은 요약 실패 상태를 목업에서 보여주기 위해 **의도적으로 실패**한다 — 버그가 아니다.
- **알림 설정에 저장 버튼이 없다.** 변경 즉시 저장 + "저장됨" 토스트가 스펙이다. 저장 버튼을 추가하지 말 것.
- **테스트 디렉토리가 없다.** 기본 생성된 `widget_test.dart`는 목업 단계에서 의미가 없어 삭제했다.
  요청받지 않았다면 테스트를 새로 만들지 않는다.
- `ponytail:` 주석은 의도적으로 단순화한 지점이다. 주석에 확장 방법이 적혀 있으니 지우지 말고 갱신한다.

## 열린 작업

- **Flutter ↔ 백엔드 미연결.** `AppStore`가 아직 인메모리다. 필요한 것: `lib/data/api.dart`(HTTP 클라이언트),
  `AppStore` 메서드 비동기화, 로그인 화면, GoRouter `/login` 리다이렉트, 토큰 보관(`flutter_secure_storage`),
  iOS `Info.plist`에 `NSAllowsLocalNetworking`(localhost 평문 HTTP 차단 해제).
- 주제는 DB에서 오지만 콘텐츠는 코드에 남는다 — `topics.slug`(`llm`/`flutter`/`design`)로 목업 아이템을
  클라이언트에서 붙일 예정. 수집기가 생기면 이 접합점만 걷어낸다.
- 수집기(RSS·YouTube)와 AI 요약, 실제 발송은 아직 없다. 클라이언트가 할 수 없는 일이라 백엔드 작업이다.
- 알림 설정 화면 미연동 채널 행에서 안내문 + "연동하기 ›" 가로 오버플로 (약 13px) — 수정 필요.
- Pretendard 미번들 → 시스템 폰트 폴백. `assets/fonts/` + `pubspec.yaml` `fonts:` 선언으로 해결.
- 썸네일·아이콘이 이모지 플레이스홀더. 실제 이미지는 `ThumbBox`만 교체.
- 주제 상세 무한 스크롤, 온보딩 완료 여부 로컬 저장 미구현.

## design-prototype.html (참고용)

최초 디자인 프로토타입. React + 사내 `dc-runtime` 번들러 출력물이고 Flutter 구현의 원본이다.
지금은 **읽기 전용 참고 자료**로만 쓴다 — 여기를 고쳐도 앱에 반영되지 않는다.

손으로 편집하지 말 것. 앱 소스 전체가 한 줄의 JSON 문자열(line 382)에 들어 있어 추출 → 편집 → 재인코딩이 필요하다.
4MB인 이유는 매니페스트에 든 Pretendard woff2 서브셋 92개다.
