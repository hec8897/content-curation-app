# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Flutter app ("큐레이터") for Korean content curation: keyword-based topics collect articles/videos
from RSS and YouTube sources, and get delivered on a schedule with AI summaries. Copy is Korean throughout.

Started as a pure UI mockup and is being wired up one piece at a time. What exists now:

- **`backend/`** — FastAPI + Postgres. 인증과 사용자 소유 데이터(주제·소스·채널·발송 설정)가 실제로 저장된다.
- **`lib/`** — Flutter 앱. `AppStore`가 로그인 직후 `GET /bootstrap`으로 불러오고, 변경은 서버 응답을 받은 뒤 반영한다.
  온보딩 완료 여부만 기기 Keychain(`curator.onboarded:<email>`)에 둔다 — 초기화는 `xcrun simctl keychain booted reset`.
- **콘텐츠 아이템** — 백엔드가 소스 피드에서 수집해 `items`에 저장하고 OpenAI로 관련성 판단 + 한국어 요약을 붙인다.
  수집은 주제 상세의 ↻ 버튼(`POST /topics/{id}/collect`)으로만 돈다 — 자동 주기 수집은 아직 없다.

```bash
cp env.example.json env.json    # 최초 1회. Google 클라이언트 ID를 채운다
xcrun simctl boot "iPhone 17"   # Xcode 27에는 Simulator.app이 없다 — open -a Simulator는 실패한다
flutter run -d "iPhone 17" --dart-define-from-file=env.json
flutter analyze                 # 무경고 상태를 유지한다
```

**`--dart-define-from-file`을 빼면** 클라이언트 ID가 빈 문자열이 되어 Google 버튼이
"클라이언트 ID를 설정하면 활성화됩니다" 안내로 바뀐다. 크래시가 아니라 조용히 비활성화되므로
Google 로그인이 안 보이면 이 플래그를 먼저 확인한다.

`flutter doctor`의 "iOS 27.0 Simulator not installed" 경고는 무시한다. iOS 26.5 런타임으로 빌드·실행 모두 된다.

## 백엔드 (`backend/`)

FastAPI + Postgres. Python 환경은 `uv`가 관리하므로 `activate`는 필요 없다 — 전부 `uv run`으로 실행한다.

```bash
cd backend
cp .env.example .env                              # 최초 1회. GOOGLE_CLIENT_ID를 채운다
docker compose up -d                              # Postgres. 한 번 띄우면 계속 돌아간다
uv run --env-file .env uvicorn app.main:app --reload --port 8000
curl localhost:8000/health                        # {"status":"ok"}
open http://localhost:8000/docs                   # 자동 생성 문서에서 바로 호출 가능
```

**`--env-file`을 빼면 `.env`가 로드되지 않는다** — uv는 자동으로 읽지 않는다. 빼고 띄우면
Google 로그인만 503이 되고 나머지는 정상 동작하므로 원인을 눈치채기 어렵다.

로컬 개발용 DB 접속 정보다. **로컬 Docker 컨테이너 전용이고 배포되지 않으므로 여기 적어둔다.**
실제 배포가 생기면 `DATABASE_URL` / `JWT_SECRET`을 환경변수로 주입하고 이 값들은 쓰지 않는다.

| | 값 |
|---|---|
| Host / Port | `localhost` / `5432` |
| Database | `curator` |
| User / Password | `curator` / `curator` |
| `DATABASE_URL` 기본값 | `postgresql+psycopg://curator:curator@localhost:5432/curator` |

런타임 설정은 `backend/.env`에서 읽는다(gitignore됨). 항목 설명은 `backend/.env.example`에 있다.
`.env`에 `KEY=`로 비워둔 값은 미설정으로 취급된다.

| 변수 | 없으면 |
|---|---|
| `JWT_SECRET` | **기동 거부.** 빈 키로 서명하면 토큰이 위조 가능하고, 고정 기본값은 그대로 배포된다 |
| `GOOGLE_CLIENT_ID` | Google 로그인 라우트만 503. 나머지는 정상 동작 |
| `OPENAI_API_KEY` | 요약만 건너뛴다. 수집은 정상이지만 판단 전 아이템은 앱에 안 보인다 |
| `SUMMARY_MODEL` | `gpt-5.6-luna` |
| `DATABASE_URL` | 위 표의 로컬 Postgres 기본값 사용 |

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
`GET /bootstrap`이 주제·소스·채널·설정과 주제별 최신 아이템 50건을 한 번에 돌려주므로 앱 진입 시 왕복이 한 번이면 된다.

수집 파이프라인은 `collector.py` → `summarizer.py`다.

- **수집:** 소스 `url`이 피드면 그대로, 사이트면 HTML의 `<link rel="alternate">`로 피드를 찾아 `sources.feed_url`에 저장한다.
  YouTube 채널 페이지도 이 링크를 노출하므로 **YouTube API 키 없이** RSS와 같은 경로다. 중복은 `(source_id, guid)` 유니크 제약이 막는다.
  한 소스가 실패해도 나머지는 계속 수집하고, 전부 실패할 때만 502다.
- **요약:** 수집 요청 안에서 새 아이템을 스레드 8개로 전부 판단한 뒤 응답한다(첫 수집 ~40초, 재수집은 새 글만이라 1초 안팎).
  한 번의 호출로 `{relevant, summary}`를 받고, 앱에는 관련 판정과 3회 실패한 아이템만 내보낸다 — 판단 전·무관은 안 보인다.
  실패는 같은 요청 안에서 3회까지 재시도하고, 이후는 아티클 상세의 "다시 시도"(`POST /items/{id}/summarize`)로만.

모든 변경 라우트는 소유권을 검사한다 — 남의 주제·소스는 404다. 이 검사를 우회하는 라우트를 새로 만들지 말 것.

## 작업은 worktree에서

`main`에서 직접 고치지 않는다. 새 작업은 worktree를 만들어(`EnterWorktree`, 위치 `.claude/worktrees/`) 브랜치에서 하고 PR로 합친다.
문서 오탈자 같은 한 줄 수정만 예외.

새 worktree에는 gitignore된 파일이 없다. 만들자마자 복사한다:

```bash
cp ../../../env.json .                       # 없으면 Google 버튼이 조용히 비활성화
cp ../../../backend/.env backend/            # 없으면 JWT_SECRET 부재로 기동 거부
flutter pub get
```

- **Postgres 컨테이너는 모든 worktree가 공유한다**(5432). 스키마를 바꾸는 worktree에서 `down -v`를 하면
  다른 worktree 데이터도 날아가므로, 대신 **같은 컨테이너에 worktree 전용 DB를 만든다**:
  `docker exec backend-db-1 psql -U curator -d curator -c "create database curator_<이름>"` 후
  그 worktree의 `backend/.env`에 `DATABASE_URL=postgresql+psycopg://curator:curator@localhost:5432/curator_<이름>`.
  스키마를 다시 만들 땐 `drop database`/`create database`로 그 DB만 초기화한다.
- 백엔드를 동시에 두 개 띄우면 포트가 겹친다 — 두 번째는 `--port 8001`로 띄우고 그 worktree의 `env.json`에 `"API_BASE": "http://localhost:8001"`.
- `backend/.venv`는 worktree마다 따로 생긴다. 첫 `uv run`이 알아서 만든다.

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
  data/store.dart            모델 + AppStore(ChangeNotifier) + 소스 추천 목록
  widgets/basics.dart        ThumbBox, 배지, 칩, 버튼, 토글, RadioRow, EmptyState,
                             Skeleton, DashedBox, showToast, showConfirmDialog, SheetScaffold
  widgets/content_card.dart  ContentCard (compact / list)
  screens/                   로그인 + 7개 화면

backend/
  docker-compose.yml         postgres:17, 볼륨 pgdata
  app/db.py                  엔진 + 세션 + Base (동기 SQLAlchemy)
  app/models.py              users / topics / sources / items / channels / delivery_settings
  app/collector.py           피드 판별 + 수집
  app/summarizer.py          OpenAI 관련성 판단 + 요약
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
- **발송이 아직 없어 수집 시각이 발송 시각을 대신한다.** 다이제스트 = 최근 24시간 수집분, 히스토리·주제 상세 그룹 = 수집일.
  발송이 생기면 `ContentItem.collectedAt`을 쓰는 이 세 곳을 발송 기록으로 바꾼다.
- **알림 설정에 저장 버튼이 없다.** 변경 즉시 저장 + "저장됨" 토스트가 스펙이다. 저장 버튼을 추가하지 말 것.
- **테스트 디렉토리가 없다.** 기본 생성된 `widget_test.dart`는 목업 단계에서 의미가 없어 삭제했다.
  요청받지 않았다면 테스트를 새로 만들지 않는다.
- `ponytail:` 주석은 의도적으로 단순화한 지점이다. 주석에 확장 방법이 적혀 있으니 지우지 말고 갱신한다.

## 열린 작업

- **연결 후 QA 미완료.** 디자인 어긋남·사용성 문제가 남아 있다. 진행 상황은 `ROADMAP.md`.
- 자동 주기 수집과 실제 발송은 아직 없다. 자동 수집은 lifespan 루프나 cron으로 `collect_sources`를 부르면 된다.
- 주제 0개일 때 소스 탭 크래시(`sources_screen.dart` `clamp(0, -1)`) — 주제 삭제 백로그와 같이 고친다.
- Pretendard 미번들 → 시스템 폰트 폴백. `assets/fonts/` + `pubspec.yaml` `fonts:` 선언으로 해결.
- 썸네일·아이콘이 이모지 플레이스홀더. 실제 이미지는 `ThumbBox`만 교체.
- 주제 상세 무한 스크롤 미구현.

## design-prototype.html (참고용)

최초 디자인 프로토타입. React + 사내 `dc-runtime` 번들러 출력물이고 Flutter 구현의 원본이다.
지금은 **읽기 전용 참고 자료**로만 쓴다 — 여기를 고쳐도 앱에 반영되지 않는다.

손으로 편집하지 말 것. 앱 소스 전체가 한 줄의 JSON 문자열(line 382)에 들어 있어 추출 → 편집 → 재인코딩이 필요하다.
4MB인 이유는 매니페스트에 든 Pretendard woff2 서브셋 92개다.
