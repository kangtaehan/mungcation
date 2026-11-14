import 'package:flutter/material.dart';

import '../core/ui.dart';

class HomeDashboard extends StatelessWidget {
  final Widget room;
  final String distance;
  final String duration;
  final bool walkInProgress;
  final VoidCallback onNotifications;
  final VoidCallback onWalk;
  final VoidCallback onMap;
  final VoidCallback onPlaces;
  final VoidCallback onDecorate;
  final VoidCallback onHistory;

  const HomeDashboard({
    super.key,
    required this.room,
    required this.distance,
    required this.duration,
    required this.walkInProgress,
    required this.onNotifications,
    required this.onWalk,
    required this.onMap,
    required this.onPlaces,
    required this.onDecorate,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 26),
        children: [
          Row(
            children: [
              const Icon(Icons.pets, color: forest, size: 36),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '멍케이션',
                  style: TextStyle(
                    color: forest,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: '알림',
                    onPressed: onNotifications,
                    icon: const Icon(Icons.notifications_none_rounded, size: 31),
                  ),
                  const Positioned(
                    right: 7,
                    top: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFEE6F68),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 9, height: 9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          room,
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onWalk,
            icon: const Icon(Icons.pets, size: 29),
            label: Text(
              walkInProgress ? '진행 중인 산책 보기' : '산책 시작하기',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
              backgroundColor: forest,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.map_outlined,
                  title: '산책 지도',
                  subtitle: '안전한 산책 경로',
                  onTap: onMap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionCard(
                  icon: Icons.storefront_outlined,
                  title: '동반 매장',
                  subtitle: '카페 · 식당 · 숙소',
                  onTap: onPlaces,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionCard(
                  icon: Icons.chair_outlined,
                  title: '내 방 꾸미기',
                  subtitle: '가구 · 아이템',
                  onTap: onDecorate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Material(
            color: const Color(0xFFF6F5EA),
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: onHistory,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 15, 14, 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '오늘의 산책 기록',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Text('더보기', style: TextStyle(color: Colors.black54)),
                        const Icon(Icons.chevron_right, color: Colors.black54),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _Stat(
                            icon: Icons.location_on,
                            value: distance,
                          ),
                        ),
                        Container(width: 1, height: 34, color: const Color(0xFFDCDCCF)),
                        Expanded(
                          child: _Stat(
                            icon: Icons.schedule,
                            value: duration,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFBF6ED),
    borderRadius: BorderRadius.circular(23),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(23),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: forest, size: 37),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                maxLines: 1,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _Stat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, color: forest, size: 28),
      const SizedBox(width: 8),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ],
  );
}
