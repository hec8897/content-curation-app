import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    ARRAY,
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _pk():
    return mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)


SUMMARY_MAX_ATTEMPTS = 3


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = _pk()
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    # Google로만 가입한 사용자는 비밀번호가 없다.
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # Google 계정의 불변 식별자. 이메일은 사용자가 바꿀 수 있어 연결 키로 쓰지 않는다.
    google_sub: Mapped[str | None] = mapped_column(
        String(255), unique=True, nullable=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    topics: Mapped[list["Topic"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        order_by="Topic.created_at",
    )
    channels: Mapped[list["Channel"]] = relationship(
        cascade="all, delete-orphan", order_by="Channel.kind"
    )
    settings: Mapped["DeliverySettings"] = relationship(
        cascade="all, delete-orphan", uselist=False
    )


class Topic(Base):
    __tablename__ = "topics"

    id: Mapped[uuid.UUID] = _pk()
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(60))
    keywords: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list)
    notify: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    user: Mapped[User] = relationship(back_populates="topics")
    sources: Mapped[list["Source"]] = relationship(
        back_populates="topic",
        cascade="all, delete-orphan",
        order_by="Source.created_at",
    )

    @property
    def items(self) -> list["Item"]:
        # ponytail: 소스별 아이템을 파이썬에서 합친다. 아이템이 수천 건이 되면 쿼리 + limit로 옮긴다.
        # 관련 판정만 보인다. 판단 실패(3회)는 "다시 시도"를 위해 남긴다.
        found = [
            i
            for s in self.sources
            for i in s.items
            if i.relevant or (i.summary is None and i.summary_attempts >= SUMMARY_MAX_ATTEMPTS)
        ]
        return sorted(found, key=lambda i: i.published_at, reverse=True)[:50]


class Source(Base):
    __tablename__ = "sources"

    id: Mapped[uuid.UUID] = _pk()
    topic_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("topics.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(120))
    # 사용자가 입력한 주소 그대로다. 피드 주소인지 사이트 주소인지는 수집기가 판별한다.
    url: Mapped[str] = mapped_column(String(500))
    # 실제로 읽는 피드 주소. url이 사이트 주소면 첫 수집 때 탐색해서 채운다.
    feed_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    protocol: Mapped[str] = mapped_column(String(16))
    glyph: Mapped[str] = mapped_column(String(8), default="🌐")
    last_collected_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    topic: Mapped[Topic] = relationship(back_populates="sources")
    items: Mapped[list["Item"]] = relationship(
        back_populates="source", cascade="all, delete-orphan"
    )


class Channel(Base):
    __tablename__ = "channels"
    __table_args__ = (UniqueConstraint("user_id", "kind"),)

    id: Mapped[uuid.UUID] = _pk()
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    kind: Mapped[str] = mapped_column(String(16))
    linked: Mapped[bool] = mapped_column(Boolean, default=False)
    enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    account: Mapped[str | None] = mapped_column(String(255), nullable=True)


class DeliverySettings(Base):
    __tablename__ = "delivery_settings"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    cycle: Mapped[str] = mapped_column(String(16), default="daily")
    send_hour: Mapped[int] = mapped_column(Integer, default=8)
    send_minute: Mapped[int] = mapped_column(Integer, default=0)


class Item(Base):
    __tablename__ = "items"
    # 재수집 시 중복을 DB가 막는다. insert ... on conflict do nothing과 짝이다.
    __table_args__ = (UniqueConstraint("source_id", "guid"),)

    id: Mapped[uuid.UUID] = _pk()
    source_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sources.id", ondelete="CASCADE"), index=True
    )
    guid: Mapped[str] = mapped_column(String(500))
    title: Mapped[str] = mapped_column(String(500))
    url: Mapped[str] = mapped_column(String(1000))
    # 피드가 준 본문/설명(HTML 포함). 요약 입력으로만 쓴다.
    content: Mapped[str] = mapped_column(Text, default="")
    published_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    collected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    # None = 아직 판단 전. False면 앱에 내보내지 않는다.
    relevant: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    summary_attempts: Mapped[int] = mapped_column(Integer, default=0)

    source: Mapped[Source] = relationship(back_populates="items")
