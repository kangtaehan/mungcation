import 'dart:io';
import 'package:flutter/foundation.dart';
import 'services/android_map_service.dart';
import 'services/android_map_configuration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/ui.dart';
import 'models/app_data.dart';
import 'services/app_controller.dart';
import 'services/local_repository.dart';
import 'services/location_source.dart';
import 'services/map_service.dart';
import 'services/national_park_map_service.dart';
import 'services/pet_friendly_map_service.dart';
import 'services/walk_session.dart';
import 'features/account_pages.dart';
import 'features/data_tools_page.dart';
import 'features/places_page.dart';
import 'features/walking_page.dart';
import 'widgets/pet_room.dart';
import 'widgets/home_dashboard.dart';

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
    builder: (context, child) => kIsWeb
        ? Column(
            children: [
              const Material(
                color: mist,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      '웹 체험 · 브라우저에만 저장돼요. 사진·파일·잠금 화면 기록은 모바일 앱에서 이용해 주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          )
        : child ?? const SizedBox.shrink(),
    theme: mungcationTheme(),
    home: Shell(
      repository: repository ?? LocalRepository(),
      locationSource: locationSource,
      maps:
          maps ??
          PetFriendlyMapService(
            NationalParkMapService(
              kIsWeb || Platform.isAndroid
                  ? AndroidMapService()
                  : AppleMapService(),
            ),
          ),
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
    if (kIsWeb || Platform.isAndroid) {
      await AndroidMapConfiguration.instance.load();
    }
    await controller.load();
    if (mounted) walk.recover();
  }

  @override
  void dispose() {
    if (widget.maps is PetFriendlyMapService)
      (widget.maps as PetFriendlyMapService).close();
    if (widget.maps is NationalParkMapService)
      (widget.maps as NationalParkMapService).close();
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
                    if (!kIsWeb)
                      OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => DataToolsPage(
                              controller: controller,
                              session: walk,
                            ),
                          ),
                        ),
                        child: const Text('백업에서 복원'),
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
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: hairline)),
          ),
          child: NavigationBar(
            elevation: 0,
            selectedIndex: selected == 4 ? 1 : selected,
            onDestinationSelected: go,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
    return HomeDashboard(
      room: PetRoom(
        equipped: data.equipped,
        equipment: data.equipment,
        name: pet.name,
        character: pet.character,
        pixelPhoto: pet.pixelPhoto,
        furniture: data.furniture,
      ),
      distance: '${(meters / 1000).toStringAsFixed(1)} km',
      duration: '${seconds ~/ 60}분',
      walkInProgress: session.hasWalk,
      onWalk: () => onGo(1),
      onMap: () => onGo(1),
      onPlaces: () => onGo(4),
      onDecorate: onDecorate,
      onHistory: () => onGo(3),
      onNotifications: () => showDialog<void>(
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
    );
  }
}
