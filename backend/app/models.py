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
    # slug은 목업 콘텐츠를 붙이기 위한 안정 키다. 사용자가 만든 주제는 NULL이고,
    # Postgres는 NULL 중복을 허용하므로 이 제약과 공존한다.
    __table_args__ = (UniqueConstraint("user_id", "slug"),)

    id: Mapped[uuid.UUID] = _pk()
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    slug: Mapped[str | None] = mapped_column(String(40), nullable=True)
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


class Source(Base):
    __tablename__ = "sources"

    id: Mapped[uuid.UUID] = _pk()
    topic_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("topics.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(120))
    # 사용자가 입력한 주소 그대로다. 피드 주소인지 사이트 주소인지는 수집기가 판별한다.
    url: Mapped[str] = mapped_column(String(500))
    protocol: Mapped[str] = mapped_column(String(16))
    glyph: Mapped[str] = mapped_column(String(8), default="🌐")
    last_collected_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    topic: Mapped[Topic] = relationship(back_populates="sources")


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
