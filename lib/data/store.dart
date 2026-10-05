import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

enum ContentKind { article, youtube }

enum SummaryStatus { pending, done, failed }

class ContentItem {
  final String id;
  final String title;
  final String source;
  final ContentKind kind;
  final DateTime publishedAt;
  // ponytail: 발송이 없어 수집 시각이 발송 시각 자리를 대신한다. 발송이 생기면 발송 기록의 시각으로 바꾼다.
  final DateTime collectedAt;
  final String? summary;
  final SummaryStatus summaryStatus;
  final String url;
  final String glyph;

  const ContentItem({
    required this.id,
    required this.title,
    required this.source,
    required this.kind,
    required this.publishedAt,
    required this.collectedAt,
    required this.summary,
    required this.summaryStatus,
    required this.url,
    this.glyph = '📄',
  });

  factory ContentItem.fromJson(Map<String, dynamic> j) => ContentItem(
        id: j['id'],
        title: j['title'],
        source: j['source']['name'],
        kind: j['source']['protocol'] == 'YouTube' ? ContentKind.youtube : ContentKind.article,
        glyph: j['source']['glyph'],
        publishedAt: DateTime.parse(j['published_at']).toLocal(),
        collectedAt: DateTime.parse(j['collected_at']).toLocal(),
        summary: j['summary'],
        summaryStatus: SummaryStatus.values.byName(j['summary_status']),
        url: j['url'],
      );

  String get kindLabel => kind == ContentKind.youtube ? '유튜브' : '아티클';
  String get dateLabel =>
      '${publishedAt.year}.${pad2(publishedAt.month)}.${pad2(publishedAt.day)}';
  String get metaLine => '$source · $kindLabel · $dateLabel';
}

class Source {
  final String id;
  final String name;
  final String url;
  final String protocol;
  final DateTime? lastCollectedAt;
  final String glyph;
  const Source({
    required this.id,
    required this.name,
    required this.url,
    required this.protocol,
    this.lastCollectedAt,
    this.glyph = '🌐',
  });

  factory Source.fromJson(Map<String, dynamic> j) => Source(
        id: j['id'],
        name: j['name'],
        url: j['url'],
        protocol: j['protocol'],
        glyph: j['glyph'],
        lastCollectedAt: j['last_collected_at'] == null ? null : DateTime.parse(j['last_collected_at']),
      );

  Map<String, dynamic> toJson() => {'name': name, 'url': url, 'protocol': protocol, 'glyph': glyph};

  /// 입력이 주소처럼 보이면 직접 추가할 소스를 만든다. 형식 검증은 서버가 한다.
  // ponytail: 이름은 호스트로 대신한다. 수집기가 생기면 피드 제목으로 바꾼다.
  static Source? fromInput(String input) {
    final text = input.trim();
    if (text.contains(' ') || !text.contains('.')) return null;
    final uri = Uri.tryParse(text.startsWith('http') ? text : 'https://$text');
    if (uri == null || uri.host.isEmpty) return null;
    final host = uri.host.replaceFirst('www.', '');
    final youtube = host == 'youtube.com' || host == 'm.youtube.com' || host == 'youtu.be';
    return Source(
      id: 'custom',
      name: youtube ? '$host${uri.path}' : host,
      url: uri.toString(),
      protocol: youtube ? 'YouTube' : 'RSS',
      glyph: youtube ? '▶️' : '🌐',
    );
  }

  String get meta =>
      lastCollectedAt == null ? '$protocol · 수집 대기 중' : '$protocol · 최근 수집 ${_ago(lastCollectedAt!)}';
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return '방금';
  if (d.inHours < 1) return '${d.inMinutes}분 전';
  if (d.inDays < 1) return '${d.inHours}시간 전';
  if (d.inDays == 1) return '어제';
  return '${d.inDays}일 전';
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

  factory Topic.fromJson(Map<String, dynamic> j) => Topic(
        id: j['id'],
        name: j['name'],
        keywords: List<String>.from(j['keywords']),
        notify: j['notify'],
        sources: [for (final s in j['sources']) Source.fromJson(s)],
        items: [for (final i in j['items']) ContentItem.fromJson(i)],
      );
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

  static const _labels = {
    'email': (name: '이메일', glyph: '✉️'),
    'slack': (name: 'Slack', glyph: '💬'),
    'push': (name: '앱 푸시', glyph: '🔔'),
  };

  factory Channel.fromJson(Map<String, dynamic> j) {
    final label = _labels[j['kind']]!;
    return Channel(
      id: j['kind'],
      name: label.name,
      glyph: label.glyph,
      linked: j['linked'],
      on: j['enabled'],
      account: j['account'],
    );
  }
}

String pad2(int n) => n.toString().padLeft(2, '0');

class AppStore extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();

  // 온보딩 완료는 기기에만 둔다. 계정마다 따로 기억하도록 이메일을 키에 넣는다.
  // 초기화: `xcrun simctl keychain booted reset` — 토큰도 함께 지워진다.
  // Keychain이라 앱 재설치로는 지워지지 않는다.
  bool onboarded = false;
  String _email = '';
  String get _onboardedKey => 'curator.onboarded:$_email';

  List<Topic> topics = [];
  List<Channel> channels = [];

  SendCycle cycle = SendCycle.daily;
  int sendHour = 8;
  int sendMinute = 0;

  Future<void> load() async {
    final b = await request('GET', '/bootstrap');
    _email = b['email'];
    topics = [for (final t in b['topics']) Topic.fromJson(t)];
    // 서버는 kind 알파벳순이라 디자인 순서(이메일·Slack·푸시)로 다시 정렬한다.
    final order = Channel._labels.keys.toList();
    channels = [for (final c in b['channels']) Channel.fromJson(c)]
      ..sort((a, b) => order.indexOf(a.id).compareTo(order.indexOf(b.id)));
    _applySettings(b['settings']);
    onboarded = await _storage.read(key: _onboardedKey) != null;
    notifyListeners();
  }

  void _applySettings(Map<String, dynamic> s) {
    cycle = SendCycle.values.byName(s['cycle']);
    sendHour = s['send_hour'];
    sendMinute = s['send_minute'];
  }

  Topic topic(String id) => topics.firstWhere((t) => t.id == id);

  // ponytail: 발송 기록이 없어 "최근 24시간 수집분"을 다이제스트로 보여준다. 발송이 생기면 발송 기록으로 바꾼다.
  List<ContentItem> get digest {
    final since = DateTime.now().subtract(const Duration(hours: 24));
    return topics.expand((t) => t.items).where((i) => i.collectedAt.isAfter(since)).toList();
  }

  List<NotificationBatch> get history {
    final byDay = <DateTime, List<ContentItem>>{};
    for (final i in topics.expand((t) => t.items)) {
      final c = i.collectedAt;
      byDay.putIfAbsent(DateTime(c.year, c.month, c.day), () => []).add(i);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final d in days) NotificationBatch(date: d, channel: '이메일', items: byDay[d]!)];
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

  Future<void> completeOnboarding(List<String> keywords, List<Source> picked) async {
    if (keywords.isNotEmpty) {
      final t = Topic.fromJson(await request('POST', '/topics', {'name': keywords.first, 'keywords': keywords}));
      if (picked.isNotEmpty) t.sources = await _postSources(t.id, picked);
      topics.add(t);
    }
    await _storage.write(key: _onboardedKey, value: '1');
    onboarded = true;
    notifyListeners();
  }

  Future<List<Source>> _postSources(String topicId, List<Source> picked) async => [
        for (final s in await request('POST', '/topics/$topicId/sources', [for (final p in picked) p.toJson()]))
          Source.fromJson(s),
      ];

  Future<void> addSources(String topicId, List<Source> picked) async {
    final added = await _postSources(topicId, picked);
    final t = topic(topicId);
    t.sources = [...t.sources, ...added];
    notifyListeners();
  }

  Future<void> removeSource(String topicId, String sourceId) async {
    await request('DELETE', '/sources/$sourceId');
    final t = topic(topicId);
    t.sources = t.sources.where((s) => s.id != sourceId).toList();
    notifyListeners();
  }

  /// 주제의 소스를 지금 수집한다. 새로 들어온 콘텐츠 수를 돌려준다.
  Future<int> collect(String topicId) async {
    final before = topic(topicId).items.map((i) => i.id).toSet();
    final updated = Topic.fromJson(await request('POST', '/topics/$topicId/collect'));
    topics = [for (final t in topics) t.id == topicId ? updated : t];
    notifyListeners();
    return updated.items.where((i) => !before.contains(i.id)).length;
  }

  void replaceItem(ContentItem updated) {
    for (final t in topics) {
      final i = t.items.indexWhere((x) => x.id == updated.id);
      if (i >= 0) t.items[i] = updated;
    }
    notifyListeners();
  }

  Future<void> addTopic(String name) async {
    topics.add(Topic.fromJson(await request('POST', '/topics', {'name': name})));
    notifyListeners();
  }

  Future<void> toggleTopicNotify(String topicId, bool value) async {
    await request('PATCH', '/topics/$topicId', {'notify': value});
    topic(topicId).notify = value;
    notifyListeners();
  }

  Future<void> _patchChannel(String id, Map<String, dynamic> body) async {
    final updated = Channel.fromJson(await request('PATCH', '/channels/$id', body));
    channels = [for (final c in channels) c.id == id ? updated : c];
    notifyListeners();
  }

  Future<void> toggleChannel(String id, bool value) => _patchChannel(id, {'enabled': value});

  // ponytail: 실제 OAuth 연동 전이라 계정 표기만 채운다. 연동이 생기면 서버가 account를 정한다.
  Future<void> linkChannel(String id) => _patchChannel(id, {
        'linked': true,
        'enabled': true,
        'account': id == 'slack' ? '#curation 채널' : _email,
      });

  Future<void> _patchSettings(Map<String, dynamic> body) async {
    _applySettings(await request('PATCH', '/settings', body));
    notifyListeners();
  }

  Future<void> setCycle(SendCycle c) => _patchSettings({'cycle': c.name});

  Future<void> setTime(int hour, int minute) => _patchSettings({'send_hour': hour, 'send_minute': minute});
}

final store = AppStore();

const searchCatalog = <Source>[
  Source(id: 'c1', name: 'GeekNews', url: 'https://news.hada.io/rss/news', protocol: 'RSS', glyph: '🟠'),
  Source(id: 'c2', name: '요즘IT', url: 'https://yozm.wishket.com/magazine/', protocol: 'RSS', glyph: '🟣'),
  Source(
    id: 'c3',
    name: 'Two Minute Papers',
    url: 'https://www.youtube.com/@TwoMinutePapers',
    protocol: 'YouTube',
    glyph: '🎬',
  ),
  Source(id: 'c4', name: '토스 기술 블로그', url: 'https://toss.tech/rss.xml', protocol: 'RSS', glyph: '🔷'),
  Source(id: 'c5', name: 'Fireship', url: 'https://www.youtube.com/@Fireship', protocol: 'YouTube', glyph: '🔥'),
  Source(
    id: 'c6',
    name: '우아한형제들 기술 블로그',
    url: 'https://techblog.woowahan.com/feed/',
    protocol: 'RSS',
    glyph: '🛵',
  ),
];

