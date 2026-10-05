import logging
import os
import uuid
from concurrent.futures import ThreadPoolExecutor

from openai import OpenAI, OpenAIError
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import models
from .models import SUMMARY_MAX_ATTEMPTS

log = logging.getLogger("uvicorn.error")

# ponytail: 비용 상한. 요약에는 앞부분이면 충분하다. 품질이 모자라면 늘린다.
_MAX_INPUT_CHARS = 20_000
_MODEL = os.environ.get("SUMMARY_MODEL", "").strip() or "gpt-5.6-luna"
_KEY = os.environ.get("OPENAI_API_KEY", "").strip()
_WORKERS = 8
_client = OpenAI(api_key=_KEY) if _KEY else None

_INSTRUCTIONS = """당신은 콘텐츠 큐레이션 앱의 편집자다.
사용자의 관심 주제와 키워드가 주어지고, 수집된 글 하나가 주어진다.
1) relevant: 이 글이 주제와 실제로 관련 있으면 true.
2) summary: 한국어 2~3문장. 글이 무엇을 다루고 독자가 무엇을 얻는지. 원문이 영어여도 한국어로 쓴다."""


class _Result(BaseModel):
    relevant: bool
    summary: str


def _prompt(item: models.Item) -> str:
    topic = item.source.topic
    return (
        f"주제: {topic.name}\n키워드: {', '.join(topic.keywords)}\n\n"
        f"제목: {item.title}\n출처: {item.source.name}\n\n{item.content[:_MAX_INPUT_CHARS]}"
    )


def _judge(item_id: uuid.UUID, prompt: str) -> _Result | None:
    # DB 세션을 건드리지 않는다 — 스레드에서 돈다.
    try:
        resp = _client.responses.parse(
            model=_MODEL, instructions=_INSTRUCTIONS, input=prompt, text_format=_Result
        )
        return resp.output_parsed
    except OpenAIError as e:
        log.warning("요약 실패 %s: %r", item_id, e)
        return None


def _apply(item: models.Item, result: _Result | None) -> None:
    item.summary_attempts += 1
    if result is not None:
        item.relevant, item.summary = result.relevant, result.summary.strip()


def summarize_item(db: Session, item: models.Item) -> None:
    if _client is None:
        return
    _apply(item, _judge(item.id, _prompt(item)))
    db.commit()


def summarize_pending(db: Session, source_ids: list[uuid.UUID]) -> None:
    # ponytail: 스레드 _WORKERS개로 동시 호출. 수집량이 늘면 Batch API(50% 할인)로 옮긴다.
    if _client is None or not source_ids:
        return
    with ThreadPoolExecutor(_WORKERS) as pool:
        for _ in range(SUMMARY_MAX_ATTEMPTS):
            pending = db.scalars(
                select(models.Item).where(
                    models.Item.source_id.in_(source_ids),
                    models.Item.summary.is_(None),
                    models.Item.summary_attempts < SUMMARY_MAX_ATTEMPTS,
                )
            ).all()
            if not pending:
                return
            prompts = [(i.id, _prompt(i)) for i in pending]
            for item, result in zip(pending, pool.map(lambda p: _judge(*p), prompts)):
                _apply(item, result)
            db.commit()
