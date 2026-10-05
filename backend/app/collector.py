import logging
from datetime import datetime, timezone
from html.parser import HTMLParser
from time import mktime
from urllib.parse import urljoin, urlparse

import feedparser
import httpx
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from . import models

log = logging.getLogger("uvicorn.error")

_FEED_TYPES = {"application/rss+xml", "application/atom+xml"}
_MAX_ENTRIES = 50
# 일부 사이트(특히 YouTube)가 기본 httpx UA에 동의 페이지나 403을 돌려준다.
_HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; CuratorBot/0.1)"}


class _FeedLinkFinder(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.href: str | None = None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if self.href is None and tag == "link" and a.get("type") in _FEED_TYPES and a.get("href"):
            self.href = a["href"]


def _fetch(client: httpx.Client, url: str) -> httpx.Response:
    r = client.get(url)
    r.raise_for_status()
    return r


def _resolve_feed(client: httpx.Client, url: str) -> tuple[str, feedparser.FeedParserDict]:
    """url이 피드면 그대로, 사이트면 <link rel=alternate>를 따라간다. YouTube 채널 페이지도 이 경로다."""
    r = _fetch(client, url)
    parsed = feedparser.parse(r.content)
    if parsed.version:
        return url, parsed
    finder = _FeedLinkFinder()
    finder.feed(r.text)
    if finder.href is None:
        raise ValueError("피드 주소를 찾지 못했습니다")
    feed_url = urljoin(str(r.url), finder.href)
    return feed_url, feedparser.parse(_fetch(client, feed_url).content)


def _published(entry) -> datetime:
    t = entry.get("published_parsed") or entry.get("updated_parsed")
    return datetime.fromtimestamp(mktime(t), timezone.utc) if t else datetime.now(timezone.utc)


def _content(entry) -> str:
    if entry.get("content"):
        return entry.content[0].get("value", "")
    return entry.get("summary", "")


def collect_source(db: Session, source: models.Source) -> int:
    with httpx.Client(timeout=10, follow_redirects=True, headers=_HEADERS) as client:
        if source.feed_url:
            parsed = feedparser.parse(_fetch(client, source.feed_url).content)
        else:
            source.feed_url, parsed = _resolve_feed(client, source.url)
            # 직접 등록한 소스는 앱이 호스트명을 이름으로 넣는다. 피드 제목이 있으면 그걸로 바꾼다.
            title = parsed.feed.get("title")
            if title and source.name == (urlparse(source.url).hostname or "").removeprefix("www."):
                source.name = title[:120]

    rows = [
        {
            "source_id": source.id,
            "guid": (e.get("id") or e.get("link"))[:500],
            "title": (e.get("title") or "(제목 없음)")[:500],
            "url": e.get("link", "")[:1000],
            "content": _content(e),
            "published_at": _published(e),
        }
        # 첫 수집에 과거 글 수백 건이 들어오지 않게 최신 글만 받는다. 피드는 보통 최신순이다.
        for e in parsed.entries[:_MAX_ENTRIES]
        if e.get("id") or e.get("link")
    ]
    inserted = 0
    if rows:
        result = db.execute(
            insert(models.Item)
            .values(rows)
            .on_conflict_do_nothing(index_elements=["source_id", "guid"])
            .returning(models.Item.id)
        )
        inserted = len(result.all())
    source.last_collected_at = datetime.now(timezone.utc)
    db.commit()
    return inserted


def collect_sources(db: Session, sources: list[models.Source]) -> int:
    """실패한 소스는 건너뛰고 나머지를 계속 수집한다. 성공한 소스 수를 돌려준다."""
    # ponytail: 소스를 순차로 읽는다. 소스가 수백 개가 되면 httpx.AsyncClient + gather로 병렬화.
    # ponytail: 같은 피드를 여러 사용자가 등록하면 각자 따로 읽는다. 부하가 되면 feed_url 단위로 묶는다.
    ok = 0
    for source in sources:
        url = source.url
        try:
            n = collect_source(db, source)
            ok += 1
            log.info("수집 %s: 신규 %d건", url, n)
        except Exception as e:
            db.rollback()
            log.warning("수집 실패 %s: %r", url, e)
    return ok
