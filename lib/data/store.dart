import 'package:flutter/foundation.dart';

enum ContentKind { article, youtube }

class ContentItem {
  final String id;
  final String title;
  final String source;
  final ContentKind kind;
  final DateTime publishedAt;
  final DateTime sentAt;
  final String summary;
  final String url;
  final String glyph;

  const ContentItem({
    required this.id,
    required this.title,
    required this.source,
    required this.kind,
    required this.publishedAt,
    required this.sentAt,
    required this.summary,
    required this.url,
    this.glyph = '📄',
  });

  String get kindLabel => kind == ContentKind.youtube ? '유튜브' : '아티클';
  String get dateLabel =>
      '${publishedAt.year}.${pad2(publishedAt.month)}.${pad2(publishedAt.day)}';
  String get metaLine => '$source · $kindLabel · $dateLabel';
}

class Source {
  final String id;
  final String name;
  final String protocol;
  final String lastCollected;
  final String glyph;
  const Source({
    required this.id,
    required this.name,
    required this.protocol,
    required this.lastCollected,
    this.glyph = '🌐',
  });
  String get meta => '$protocol · 최근 수집 $lastCollected';
}

class Topic {
  final String id;
  String name;
  List<String> keywords;
  List<Source> sources;
  List<ContentItem> items;
  bool notify;

  Topic({
    required this.id,
    required this.name,
    this.keywords = const [],
    this.sources = const [],
    this.items = const [],
    this.notify = true,
  });
}

class NotificationBatch {
  final DateTime date;
  final String channel;
  final List<ContentItem> items;
  const NotificationBatch({required this.date, required this.channel, required this.items});
  String get dateLabel => '${date.month}월 ${date.day}일';
}

enum SendCycle { daily, weekdays, weekly }

class Channel {
  final String id;
  final String name;
  final String glyph;
  bool linked;
  bool on;
  String? account;
  Channel({
    required this.id,
    required this.name,
    required this.glyph,
    this.linked = false,
    this.on = false,
    this.account,
  });
}

String pad2(int n) => n.toString().padLeft(2, '0');

// ponytail: 목업 전용 인메모리 스토어. 백엔드 붙일 때 이 파일만 리포지토리로 교체하면 된다.
class AppStore extends ChangeNotifier {
  bool onboarded = false;

  final List<Topic> topics = [
    Topic(
      id: 'llm',
      name: 'LLM 에이전트',
      keywords: ['LLM', '에이전트', 'RAG'],
      notify: true,
      sources: const [
        Source(id: 's1', name: 'Simon Willison', protocol: 'RSS', lastCollected: '3시간 전', glyph: '📰'),
        Source(id: 's2', name: 'Anthropic Engineering', protocol: 'RSS', lastCollected: '1시간 전', glyph: '🧠'),
        Source(id: 's3', name: 'Lex Fridman', protocol: 'YouTube', lastCollected: '어제', glyph: '🎙'),
      ],
      items: _llmItems,
    ),
    Topic(
      id: 'flutter',
      name: 'Flutter 성능',
      keywords: ['Flutter', 'Impeller'],
      notify: false,
      sources: const [
        Source(id: 's4', name: 'Flutter Blog', protocol: 'RSS', lastCollected: '5시간 전', glyph: '💙'),
        Source(id: 's5', name: 'Flutter Dev', protocol: 'YouTube', lastCollected: '2일 전', glyph: '▶️'),
      ],
      items: _flutterItems,
    ),
    Topic(id: 'design', name: '디자인 시스템', keywords: ['디자인 토큰'], sources: const [], items: const []),
  ];

  final List<Channel> channels = [
    Channel(id: 'email', name: '이메일', glyph: '✉️', linked: true, on: true, account: 'dawoon@example.com'),
    Channel(id: 'slack', name: 'Slack', glyph: '💬'),
    Channel(id: 'push', name: '앱 푸시', glyph: '🔔', linked: true, on: false),
  ];

  SendCycle cycle = SendCycle.daily;
  int sendHour = 8;
  int sendMinute = 0;

  Topic topic(String id) => topics.firstWhere((t) => t.id == id);

  List<ContentItem> get digest =>
      topics.expand((t) => t.items).where((i) => i.sentAt.day == 14).toList();

  List<NotificationBatch> get history {
    final all = topics.expand((t) => t.items).toList();
    final byDay = <int, List<ContentItem>>{};
    for (final i in all) {
      byDay.putIfAbsent(i.sentAt.day, () => []).add(i);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return days
        .map((d) => NotificationBatch(
              date: DateTime(2026, 9, d),
              channel: '이메일',
              items: byDay[d]!,
            ))
        .toList();
  }

  ContentItem? item(String id) {
    for (final t in topics) {
      for (final i in t.items) {
        if (i.id == id) return i;
      }
    }
    return null;
  }

  List<ContentItem> siblings(String context, String itemId) {
    if (context == 'digest') return digest;
    for (final t in topics) {
      if (t.items.any((i) => i.id == itemId)) return t.items;
    }
    return const [];
  }

  String get cycleLabel => switch (cycle) {
        SendCycle.daily => '매일',
        SendCycle.weekdays => '평일만',
        SendCycle.weekly => '주 1회',
      };

  String get timeLabel {
    final am = sendHour < 12;
    final h = sendHour % 12 == 0 ? 12 : sendHour % 12;
    return '${am ? "오전" : "오후"} $h:${pad2(sendMinute)}';
  }

  List<Channel> get activeChannels => channels.where((c) => c.linked && c.on).toList();
  int get notifyingTopicCount => topics.where((t) => t.notify).length;

  String get summaryBanner {
    if (activeChannels.isEmpty) return '켜진 알림 채널이 없어요. 채널을 켜야 새 콘텐츠를 받을 수 있어요.';
    final names = activeChannels.map((c) => c.name).join(' · ');
    return '지금 설정: $cycleLabel $timeLabel, $names 채널로 주제 $notifyingTopicCount개의 새 콘텐츠를 보내드려요';
  }

  void completeOnboarding(List<String> keywords, List<Source> picked) {
    onboarded = true;
    if (keywords.isNotEmpty) {
      topics.insert(
        0,
        Topic(
          id: 'new-${DateTime.now().millisecondsSinceEpoch}',
          name: keywords.first,
          keywords: keywords,
          sources: picked,
          items: const [],
        ),
      );
    }
    notifyListeners();
  }

  void addSources(String topicId, List<Source> picked) {
    final t = topic(topicId);
    t.sources = [...t.sources, ...picked];
    notifyListeners();
  }

  void removeSource(String topicId, String sourceId) {
    final t = topic(topicId);
    t.sources = t.sources.where((s) => s.id != sourceId).toList();
    notifyListeners();
  }

  void addTopic(String name) {
    topics.add(Topic(id: 'new-${DateTime.now().millisecondsSinceEpoch}', name: name));
    notifyListeners();
  }

  void toggleTopicNotify(String topicId, bool value) {
    topic(topicId).notify = value;
    notifyListeners();
  }

  void toggleChannel(String id, bool value) {
    channels.firstWhere((c) => c.id == id).on = value;
    notifyListeners();
  }

  void linkChannel(String id) {
    final c = channels.firstWhere((ch) => ch.id == id);
    c.linked = true;
    c.on = true;
    c.account = c.id == 'slack' ? '#curation 채널' : 'dawoon@example.com';
    notifyListeners();
  }

  void setCycle(SendCycle c) {
    cycle = c;
    notifyListeners();
  }

  void setTime(int hour, int minute) {
    sendHour = hour;
    sendMinute = minute;
    notifyListeners();
  }
}

final store = AppStore();

const searchCatalog = <Source>[
  Source(id: 'c1', name: 'Hacker News', protocol: 'RSS', lastCollected: '방금', glyph: '🟠'),
  Source(id: 'c2', name: 'The Verge', protocol: 'RSS', lastCollected: '방금', glyph: '🟣'),
  Source(id: 'c3', name: 'Two Minute Papers', protocol: 'YouTube', lastCollected: '방금', glyph: '🎬'),
  Source(id: 'c4', name: 'Vercel Blog', protocol: 'RSS', lastCollected: '방금', glyph: '▲'),
  Source(id: 'c5', name: 'Fireship', protocol: 'YouTube', lastCollected: '방금', glyph: '🔥'),
  Source(id: 'c6', name: 'Stratechery', protocol: 'RSS', lastCollected: '방금', glyph: '📈'),
];

final _llmItems = <ContentItem>[
  ContentItem(
    id: 'a1',
    title: '에이전트 루프를 단순하게 유지하는 방법: 툴 호출 설계 원칙 7가지',
    source: 'Simon Willison',
    kind: ContentKind.article,
    publishedAt: DateTime(2026, 9, 12),
    sentAt: DateTime(2026, 9, 14),
    glyph: '🧩',
    url: 'https://simonwillison.net',
    summary:
        '에이전트가 복잡해지는 원인은 대부분 툴 스키마가 모호해서 생기는 재시도다. 저자는 툴을 명사가 아니라 동사 단위로 쪼개고, '
        '실패 응답에 다음 행동을 명시하라고 권한다. 또한 상태를 프롬프트가 아닌 외부 저장소에 두면 루프가 짧아진다는 실측을 함께 제시한다.',
  ),
  ContentItem(
    id: 'a2',
    title: 'RAG는 죽지 않았다 — 긴 컨텍스트 모델과 검색을 함께 쓰는 실전 구성',
    source: 'Anthropic Engineering',
    kind: ContentKind.article,
    publishedAt: DateTime(2026, 9, 13),
    sentAt: DateTime(2026, 9, 14),
    glyph: '🔍',
    url: 'https://www.anthropic.com/engineering',
    summary:
        '컨텍스트 창이 커져도 검색은 여전히 비용과 정확도 양쪽에서 이득이다. 핵심은 검색 결과를 문서 단위가 아닌 '
        '질문 단위로 재구성하는 것. 캐싱과 결합하면 동일 품질에서 토큰 비용을 60%까지 줄인 사례를 소개한다.',
  ),
  ContentItem(
    id: 'a3',
    title: '[영상] 에이전트 평가를 자동화한 1년의 기록',
    source: 'Lex Fridman',
    kind: ContentKind.youtube,
    publishedAt: DateTime(2026, 9, 11),
    sentAt: DateTime(2026, 9, 14),
    glyph: '🎙',
    url: 'https://youtube.com',
    summary:
        '수동 QA로는 회귀를 잡을 수 없다는 문제의식에서 출발해, LLM 심판을 이중화하고 사람 라벨을 샘플링으로만 쓰는 파이프라인을 설명한다. '
        '지표 하나에 최적화하면 반드시 다른 축이 무너진다는 경고가 인상적이다.',
  ),
  ContentItem(
    id: 'a4',
    title: '툴 사용 모델의 실패 모드 분류: 환각·과호출·조기 종료',
    source: 'Simon Willison',
    kind: ContentKind.article,
    publishedAt: DateTime(2026, 9, 8),
    sentAt: DateTime(2026, 9, 7),
    glyph: '🧪',
    url: 'https://simonwillison.net',
    summary: '실패를 세 갈래로 나누면 각각 다른 처방이 필요하다는 점을 실제 트레이스로 보여준다.',
  ),
];

final _flutterItems = <ContentItem>[
  ContentItem(
    id: 'b1',
    title: 'Impeller가 셰이더 컴파일 재킹크를 없앤 방식',
    source: 'Flutter Blog',
    kind: ContentKind.article,
    publishedAt: DateTime(2026, 9, 13),
    sentAt: DateTime(2026, 9, 14),
    glyph: '💙',
    url: 'https://medium.com/flutter',
    summary:
        '런타임 셰이더 컴파일을 빌드 타임으로 옮긴 것이 핵심이다. 파이프라인을 미리 알 수 있는 구조로 바꿨기 때문에 '
        '첫 프레임 재킹크가 구조적으로 사라졌다는 설명과 함께 프로파일 캡처 방법을 안내한다.',
  ),
  ContentItem(
    id: 'b2',
    title: '[영상] 리스트 성능을 3배 올린 리빌드 추적법',
    source: 'Flutter Dev',
    kind: ContentKind.youtube,
    publishedAt: DateTime(2026, 9, 10),
    sentAt: DateTime(2026, 9, 7),
    glyph: '▶️',
    url: 'https://youtube.com',
    summary: 'DevTools 리빌드 카운터로 범인을 좁히고, const 위젯과 키 전략으로 해결하는 과정을 실시간으로 보여준다.',
  ),
];
