import os

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

# 빈 문자열도 미설정으로 취급한다 — .env에 `DATABASE_URL=`로 비워둔 경우를 기본값으로 흘린다.
DATABASE_URL = (
    os.environ.get("DATABASE_URL", "").strip()
    or "postgresql+psycopg://curator:curator@localhost:5432/curator"
)

# ponytail: 동기 엔진. FastAPI가 sync 엔드포인트를 스레드풀에서 돌려주므로 프로토타입 부하에는 충분하다.
# 수집기가 외부 HTTP를 병렬로 때리기 시작하면 asyncpg + AsyncSession으로 옮긴다.
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    with SessionLocal() as session:
        yield session
