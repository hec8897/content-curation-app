import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import Depends, FastAPI, HTTPException, status
from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from . import models
from .auth import BCRYPT_MAX_BYTES, create_token, current_user, hash_password, verify_password
from .db import Base, engine, get_db


@asynccontextmanager
async def lifespan(_: FastAPI):
    # ponytail: 마이그레이션 도구 없이 시작 시 테이블 생성. 스키마를 바꾸면 `docker compose down -v`로
    # 초기화한다. 지울 수 없는 데이터가 생기는 시점에 Alembic을 도입한다.
    Base.metadata.create_all(engine)
    yield


app = FastAPI(title="Curator API", lifespan=lifespan)


class Credentials(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)

    @field_validator("password")
    @classmethod
    def _within_bcrypt_limit(cls, v: str) -> str:
        # bcrypt는 72바이트를 넘는 입력을 거부한다. 한글은 글자당 3바이트라 길이 제한만으로는 부족하다.
        if len(v.encode()) > BCRYPT_MAX_BYTES:
            raise ValueError(f"비밀번호는 UTF-8 기준 {BCRYPT_MAX_BYTES}바이트를 넘을 수 없습니다")
        return v


class TokenOut(BaseModel):
    token: str


class SourceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    name: str
    protocol: str
    glyph: str
    last_collected_at: datetime | None


class TopicOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    slug: str | None
    name: str
    keywords: list[str]
    notify: bool
    sources: list[SourceOut]


class ChannelOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    kind: str
    linked: bool
    enabled: bool
    account: str | None


class SettingsOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    cycle: str
    send_hour: int
    send_minute: int


class Bootstrap(BaseModel):
    email: str
    topics: list[TopicOut]
    channels: list[ChannelOut]
    settings: SettingsOut


class TopicIn(BaseModel):
    name: str = Field(min_length=1, max_length=60)
    keywords: list[str] = []


class TopicPatch(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=60)
    notify: bool | None = None


class SourceIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    protocol: Literal["RSS", "YouTube"]
    glyph: str = "🌐"


class ChannelPatch(BaseModel):
    linked: bool | None = None
    enabled: bool | None = None
    account: str | None = None


class SettingsPatch(BaseModel):
    cycle: Literal["daily", "weekdays", "weekly"] | None = None
    send_hour: int | None = Field(default=None, ge=0, le=23)
    send_minute: int | None = Field(default=None, ge=0, le=59)


def _ago(**kwargs) -> datetime:
    return datetime.now(timezone.utc) - timedelta(**kwargs)


# ponytail: 가입 직후 앱이 목업과 같은 모습이 되도록 심는 시드다.
# 실제 수집기가 붙으면 주제 시드는 걷어내고 채널·설정 시드만 남긴다.
def _seed(db: Session, user: models.User) -> None:
    db.add_all(
        [
            models.Channel(
                user_id=user.id, kind="email", linked=True, enabled=True, account=user.email
            ),
            models.Channel(user_id=user.id, kind="slack"),
            models.Channel(user_id=user.id, kind="push", linked=True),
            models.DeliverySettings(user_id=user.id),
        ]
    )
    llm = models.Topic(
        user_id=user.id,
        slug="llm",
        name="LLM 에이전트",
        keywords=["LLM", "에이전트", "RAG"],
        notify=True,
        sources=[
            models.Source(
                name="Simon Willison", protocol="RSS", glyph="📰", last_collected_at=_ago(hours=3)
            ),
            models.Source(
                name="Anthropic Engineering",
                protocol="RSS",
                glyph="🧠",
                last_collected_at=_ago(hours=1),
            ),
            models.Source(
                name="Lex Fridman", protocol="YouTube", glyph="🎙", last_collected_at=_ago(days=1)
            ),
        ],
    )
    flutter = models.Topic(
        user_id=user.id,
        slug="flutter",
        name="Flutter 성능",
        keywords=["Flutter", "Impeller"],
        notify=False,
        sources=[
            models.Source(
                name="Flutter Blog", protocol="RSS", glyph="💙", last_collected_at=_ago(hours=5)
            ),
            models.Source(
                name="Flutter Dev", protocol="YouTube", glyph="▶️", last_collected_at=_ago(days=2)
            ),
        ],
    )
    design = models.Topic(
        user_id=user.id, slug="design", name="디자인 시스템", keywords=["디자인 토큰"]
    )
    db.add_all([llm, flutter, design])


def _own_topic(db: Session, user: models.User, topic_id: uuid.UUID) -> models.Topic:
    topic = db.get(models.Topic, topic_id)
    if topic is None or topic.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "주제를 찾을 수 없습니다")
    return topic


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/auth/signup", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
def signup(body: Credentials, db: Session = Depends(get_db)) -> TokenOut:
    user = models.User(email=body.email.lower(), password_hash=hash_password(body.password))
    db.add(user)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "이미 가입된 이메일입니다")
    _seed(db, user)
    db.commit()
    return TokenOut(token=create_token(user.id))


@app.post("/auth/login", response_model=TokenOut)
def login(body: Credentials, db: Session = Depends(get_db)) -> TokenOut:
    user = db.scalar(select(models.User).where(models.User.email == body.email.lower()))
    # 계정 존재 여부를 응답으로 구분하지 않는다.
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "이메일 또는 비밀번호가 올바르지 않습니다")
    return TokenOut(token=create_token(user.id))


@app.get("/bootstrap", response_model=Bootstrap)
def bootstrap(user: models.User = Depends(current_user)) -> models.User:
    return user


@app.post("/topics", response_model=TopicOut, status_code=status.HTTP_201_CREATED)
def create_topic(
    body: TopicIn,
    user: models.User = Depends(current_user),
    db: Session = Depends(get_db),
) -> models.Topic:
    topic = models.Topic(user_id=user.id, name=body.name, keywords=body.keywords)
    db.add(topic)
    db.commit()
    db.refresh(topic)
    return topic


@app.patch("/topics/{topic_id}", response_model=TopicOut)
def update_topic(
    topic_id: uuid.UUID,
    body: TopicPatch,
    user: models.User = Depends(current_user),
    db: Session = Depends(get_db),
) -> models.Topic:
    topic = _own_topic(db, user, topic_id)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(topic, field, value)
    db.commit()
    db.refresh(topic)
    return topic


@app.post(
    "/topics/{topic_id}/sources",
    response_model=list[SourceOut],
    status_code=status.HTTP_201_CREATED,
)
def add_sources(
    topic_id: uuid.UUID,
    body: list[SourceIn],
    user: models.User = Depends(current_user),
    db: Session = Depends(get_db),
) -> list[models.Source]:
    topic = _own_topic(db, user, topic_id)
    added = [models.Source(topic_id=topic.id, **s.model_dump()) for s in body]
    db.add_all(added)
    db.commit()
    for s in added:
        db.refresh(s)
    return added


@app.delete("/sources/{source_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_source(
    source_id: uuid.UUID,
    user: models.User = Depends(current_user),
    db: Session = Depends(get_db),
) -> None:
    source = db.get(models.Source, source_id)
    if source is None or source.topic.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "소스를 찾을 수 없습니다")
    db.delete(source)
    db.commit()


@app.patch("/channels/{kind}", response_model=ChannelOut)
def update_channel(
    kind: Literal["email", "slack", "push"],
    body: ChannelPatch,
    user: models.User = Depends(current_user),
    db: Session = Depends(get_db),
) -> models.Channel:
    channel = db.scalar(
        select(models.Channel).where(
            models.Channel.user_id == user.id, models.Channel.kind == kind
        )
    )
    if channel is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "채널을 찾을 수 없습니다")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(channel, field, value)
    db.commit()
    db.refresh(channel)
    return channel


@app.patch("/settings", response_model=SettingsOut)
def update_settings(
    body: SettingsPatch,
    user: models.User = Depends(current_user),
    db: Session = Depends(get_db),
) -> models.DeliverySettings:
    settings = user.settings
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(settings, field, value)
    db.commit()
    db.refresh(settings)
    return settings
