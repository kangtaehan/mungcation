import 'dart:io';
import 'services/android_map_service.dart';
import 'services/android_map_configuration.dart';
import 'features/data_tools_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/ui.dart';
import 'models/app_data.dart';
import 'services/app_controller.dart';
import 'services/local_repository.dart';
import 'services/location_source.dart';
import 'services/map_service.dart';
import 'services/walk_session.dart';
import 'features/account_pages.dart';
import 'features/places_page.dart';
import 'features/walking_page.dart';
import 'widgets/pet_room.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MungcationApp());
}

class MungcationApp extends StatelessWidget {
  final AppRepository? repository;
  final LocationSource? locationSource;
  final MapService? maps;
  const MungcationApp({
    super.key,
    this.repository,
    this.locationSource,
    this.maps,
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '멍케이션',
    locale: const Locale('ko', 'KR'),
    supportedLocales: const [Locale('ko', 'KR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFAF8F4),
      colorScheme: ColorScheme.fromSeed(seedColor: forest, primary: forest),
    ),
    home: Shell(
      repository: repository ?? LocalRepository(),
      locationSource: locationSource,
      maps:
          maps ??
          (Platform.isAndroid ? AndroidMapService() : AppleMapService()),
    ),
  );
}

class Shell extends StatefulWidget {
  final AppRepository repository;
  final LocationSource? locationSource;
  final MapService maps;
  const Shell({
    super.key,
    required this.repository,
    this.locationSource,
    required this.maps,
  });
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late final AppController controller;
  late final WalkSession walk;
  final walkingKey = GlobalKey<WalkingPageState>();
  int selected = 0;
  @override
  void initState() {
    super.initState();
    controller = AppController(widget.repository);
    walk = WalkSession(controller, source: widget.locationSource);
    initialize();
  }

  Future<void> initialize() async {
    if (Platform.isAndroid) await AndroidMapConfiguration.instance.load();
    await controller.load();
    if (mounted) walk.recover();
  }

  @override
  void dispose() {
    if (widget.maps is AndroidMapService)
      (widget.maps as AndroidMapService).close();
    walk.dispose();
    controller.dispose();
    super.dispose();
  }

  void go(int n) => setState(() => selected = n);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.loading)
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(semanticsLabel: '데이터 불러오는 중'),
          ),
        );
      if (controller.error != null)
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(controller.error!),
                    TextButton(
                      onPressed: initialize,
                      child: const Text('다시 시도'),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => DataToolsPage(
                            controller: controller,
                            session: walk,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.restore),
                      label: const Text('백업에서 복원'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      if (controller.data.pet == null)
        return Scaffold(
          body: SafeArea(child: PetEditor(controller: controller)),
        );
      return Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: selected,
            children: [
              HomePage(
                data: controller.data,
                onGo: go,
                onDecorate: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RoomEditor(controller: controller),
                  ),
                ),
                session: walk,
              ),
              WalkingPage(
                key: walkingKey,
                visible: selected == 1,
                controller: controller,
                session: walk,
                maps: widget.maps,
              ),
              ShopPage(controller: controller),
              ProfilePage(controller: controller, session: walk),
              PlacesSearchPage(
                controller: controller,
                maps: widget.maps,
                session: walk,
                onBack: () => go(0),
                onDestination: (place) {
                  go(1);
                  walkingKey.currentState?.routeTo(place, closeSheet: false);
                },
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          height: 70,
          selectedIndex: selected == 4 ? 1 : selected,
          onDestinationSelected: go,
          indicatorColor: const Color(0xFFE8F0E7),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: '지도',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: '상점',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '마이',
            ),
          ],
        ),
      );
    },
  );
}

class HomePage extends StatelessWidget {
  final AppData data;
  final ValueChanged<int> onGo;
  final VoidCallback onDecorate;
  final WalkSession session;
  const HomePage({
    super.key,
    required this.data,
    required this.onGo,
    required this.onDecorate,
    required this.session,
  });
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(), pet = data.pet!;
    final today = data.realWalks.where(
      (w) =>
          w.startedAt.year == now.year &&
          w.startedAt.month == now.month &&
          w.startedAt.day == now.day,
    );
    final meters = today.fold<double>(0, (a, w) => a + w.meters),
        seconds = today.fold<int>(0, (a, w) => a + w.seconds);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      children: [
        Row(
          children: [
            const Icon(Icons.pets, color: forest, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '멍케이션',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: forest,
                ),
              ),
            ),
            IconButton(
              tooltip: '알림',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('오늘의 소식'),
                  content: Text(
                    session.hasWalk
                        ? '진행 중인 산책이 있어요. 지도에서 이어가거나 종료해 주세요.'
                        : today.isNotEmpty
                        ? '오늘 ${today.length}번의 산책을 기록했어요. ${pet.name}와 충분히 쉬어 주세요.'
                        : '아직 오늘의 산책 기록이 없어요. ${pet.name}의 컨디션에 맞춰 가볍게 걸어 보세요.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.notifications_none),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '${pet.name}, 오늘도 함께 걸을까요?',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${data.coins} P',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: forest,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PetRoom(
          equipped: data.equipped,
          equipment: data.equipment,
          name: pet.name,
          character: pet.character,
          pixelPhoto: pet.pixelPhoto,
          furniture: data.furniture,
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: session,
          builder: (context, _) => FilledButton.icon(
            onPressed: () => onGo(1),
            icon: const Icon(Icons.pets),
            label: Text(
              session.hasWalk ? '진행 중인 산책 보기' : '산책 시작하기',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(62),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            QuickAction(
              icon: Icons.map_outlined,
              title: '산책 지도',
              onTap: () => onGo(1),
            ),
            const SizedBox(width: 8),
            QuickAction(
              icon: Icons.storefront_outlined,
              title: '동반 매장',
              onTap: () => onGo(4),
            ),
            const SizedBox(width: 8),
            QuickAction(
              icon: Icons.chair_outlined,
              title: '내 방 꾸미기',
              onTap: onDecorate,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: beige,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '오늘의 산책',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    Text('${(meters / 1000).toStringAsFixed(2)} km'),
                    Text(durationLabel(seconds)),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Lv.${data.level} · 경험치 ${data.xp % 100}/100'),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: (data.xp % 100) / 100),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '산책 경로와 사진은 기기에 저장돼요. 실제 위치 기록은 산책에 동의한 후 시작돼요.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const QuickAction({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: beige,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, color: forest, size: 26),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
