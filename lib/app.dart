import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/store.dart';
import 'design/app_colors.dart';
import 'design/app_text.dart';
import 'screens/article_detail_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sources_screen.dart';
import 'screens/topic_detail_screen.dart';

final _router = GoRouter(
  initialLocation: store.onboarded ? '/' : '/onboarding',
  routes: [
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    GoRoute(
      path: '/article/:articleId',
      builder: (_, state) => ArticleDetailScreen(
        articleId: state.pathParameters['articleId']!,
        origin: state.uri.queryParameters['from'] ?? 'topic',
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => _TabScaffold(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const HomeScreen(),
            routes: [
              GoRoute(
                path: 'topic/:topicId',
                builder: (_, state) => TopicDetailScreen(topicId: state.pathParameters['topicId']!),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/sources',
            builder: (_, state) => SourcesScreen(topicId: state.uri.queryParameters['topicId']),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        ]),
      ],
    ),
  ],
);

class CuratorApp extends StatelessWidget {
  const CuratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '큐레이터',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        splashFactory: InkSparkle.splashFactory,
      ),
    );
  }
}

class _TabScaffold extends StatelessWidget {
  const _TabScaffold({required this.shell});
  final StatefulNavigationShell shell;

  static const _tabs = [
    (icon: Icons.home_rounded, label: '홈'),
    (icon: Icons.rss_feed_rounded, label: '소스'),
    (icon: Icons.notifications_rounded, label: '알림'),
    (icon: Icons.settings_rounded, label: '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.fill)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: GestureDetector(
                      // 탭 전환 시 해당 탭 스택 초기화
                      onTap: () => shell.goBranch(i, initialLocation: true),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _tabs[i].icon,
                            size: 19,
                            color: i == shell.currentIndex ? AppColors.labelNormal : AppColors.labelAlt,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tabs[i].label,
                            style: i == shell.currentIndex
                                ? AppText.caption2.w600.c(AppColors.labelNormal)
                                : AppText.caption2.w500.c(AppColors.labelAlt),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
