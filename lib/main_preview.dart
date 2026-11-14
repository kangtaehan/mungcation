import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/ui.dart';
import 'models/catalog.dart';
import 'widgets/pet_room.dart';
import 'widgets/home_dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MungcationPreviewApp());
}

class MungcationPreviewApp extends StatelessWidget {
  const MungcationPreviewApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '멍케이션 미리보기',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko', 'KR'),
    supportedLocales: const [Locale('ko', 'KR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFAF8F4),
      colorScheme: ColorScheme.fromSeed(seedColor: forest, primary: forest),
    ),
    home: const PreviewShell(),
  );
}

class PreviewShell extends StatefulWidget {
  const PreviewShell({super.key});
  @override
  State<PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<PreviewShell> {
  static const _equipmentKey = 'mungcation.preview.equipment';
  int tab = 0;
  int previewPlace = -1;
  bool walking = false;
  Set<String> equipment = {'ribbon'};
  final furniture = <String, List<double>>{
    'plant': [.1, .55],
    'ball': [.68, .68],
  };

  @override
  void initState() {
    super.initState();
    loadEquipment();
  }

  Future<void> loadEquipment() async {
    try {
      final saved = await SharedPreferencesAsync().getStringList(_equipmentKey);
      if (mounted && saved != null) setState(() => equipment = saved.toSet());
    } catch (_) {
      // Widget tests and private browsing can run without persistent storage.
    }
  }

  Future<void> toggle(Cosmetic item) async {
    final next = {...equipment};
    if (next.contains(item.id)) {
      next.remove(item.id);
    } else {
      final sameSlot = cosmetics.where(
        (other) => slotFor(other.id) == slotFor(item.id),
      );
      next.removeAll(sameSlot.map((e) => e.id));
      next.add(item.id);
    }
    try {
      await SharedPreferencesAsync().setStringList(
        _equipmentKey,
        next.toList(),
      );
    } catch (_) {
      // Keep the current preview session usable when browser storage is blocked.
    }
    if (mounted) setState(() => equipment = next);
  }

  void previewOnly(String feature) =>
      feedback(context, '$feature 기능은 TestFlight로 설치한 iOS 앱에서 확인해 주세요.');

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF1C7),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'Safari 미리보기 · GPS, 카메라, 파일 저장은 실제 iOS 앱에서 확인',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(child: [home(), walk(), shop(), profile()][tab]),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      height: 78,
      backgroundColor: const Color(0xFFFFFCF8),
      elevation: 0,
      indicatorColor: Colors.transparent,
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
        NavigationDestination(icon: Icon(Icons.map_outlined), label: '지도'),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          label: '상점',
        ),
        NavigationDestination(icon: Icon(Icons.pets_outlined), label: '마이'),
      ],
    ),
  );

  Widget page(List<Widget> children) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(padding: const EdgeInsets.all(20), children: children),
    ),
  );

  Widget home() => HomeDashboard(
    room: PetRoom(
      equipped: 'none',
      equipment: equipment,
      name: '몽이',
      character: 'original',
      furniture: furniture,
      onMove: (id, position) => setState(() => furniture[id] = position),
    ),
    distance: '2.8 km',
    duration: '42분',
    walkInProgress: walking,
    onWalk: () => setState(() => tab = 1),
    onMap: () => setState(() => tab = 1),
    onPlaces: () => previewOnly('동반 매장 검색'),
    onDecorate: () => setState(() => tab = 2),
    onHistory: () => setState(() => tab = 3),
    onNotifications: () => feedback(context, '새로운 산책 알림이 있어요.'),
  );

  Widget walk() => page([
    const Text(
      '산책',
      style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 14),
    AspectRatio(
      aspectRatio: 1.35,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: GestureDetector(
          onTapUp: (details) {
            final width = MediaQuery.sizeOf(context).width - 40;
            setState(
              () => previewPlace = details.localPosition.dx < width / 2 ? 0 : 1,
            );
          },
          child: CustomPaint(
            painter: PreviewMapPainter(selectedPlace: previewPlace),
          ),
        ),
      ),
    ),
    const SizedBox(height: 10),
    const Text('지도 위 장소를 눌러 산책 경로를 선택해 보세요.'),
    if (previewPlace >= 0) ...[
      const SizedBox(height: 10),
      Card(
        color: const Color(0xFFF6F1E7),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                previewPlace == 0 ? '망원 반려견 놀이터' : '멍멍 동반 카페',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(previewPlace == 0 ? '1.8 km · 약 28분' : '2.6 km · 약 39분'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  setState(() => walking = true);
                  previewOnly('강아지 내비게이션 산책');
                },
                icon: const Icon(Icons.pets),
                label: const Text('이 경로로 산책 시작'),
              ),
            ],
          ),
        ),
      ),
    ],
    const SizedBox(height: 14),
    Row(
      children: const [
        Expanded(child: _Metric('거리', '1.24 km')),
        SizedBox(width: 10),
        Expanded(child: _Metric('시간', '24분 18초')),
        SizedBox(width: 10),
        Expanded(child: _Metric('보상', '+30 P')),
      ],
    ),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: () {
        setState(() => walking = !walking);
        previewOnly('실제 GPS 산책 기록');
      },
      icon: Icon(walking ? Icons.pause : Icons.play_arrow),
      label: Text(walking ? '미리보기 일시정지' : '산책 시작'),
    ),
  ]);

  Widget shop() => page([
    const Text(
      '꾸미기 상점',
      style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
    ),
    const Text('장착 상태는 이 브라우저에 저장돼요.'),
    const SizedBox(height: 12),
    for (final item in cosmetics)
      Card(
        child: ListTile(
          leading: Text(item.emoji, style: const TextStyle(fontSize: 30)),
          title: Text(item.name),
          subtitle: Text('${item.price}P · Lv.${item.minLevel}'),
          trailing: FilledButton.tonal(
            onPressed: () => toggle(item),
            child: Text(equipment.contains(item.id) ? '해제' : '장착'),
          ),
        ),
      ),
  ]);

  Widget profile() => page([
    const Text(
      '마이',
      style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 12),
    const Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(Icons.pets)),
        title: Text('몽이'),
        subtitle: Text('믹스견 · 3살 · 소형견 · 활발함'),
      ),
    ),
    const Card(
      child: ListTile(
        leading: Icon(Icons.calendar_month),
        title: Text('전체 기록 · 통계 · 달력'),
        subtitle: Text('12회 · 18.6km · 5시간 42분'),
      ),
    ),
    Card(
      child: ListTile(
        leading: const Icon(Icons.photo_camera_outlined),
        title: const Text('사진과 픽셀 캐릭터'),
        onTap: () => previewOnly('카메라와 사진 선택'),
      ),
    ),
    Card(
      child: ListTile(
        leading: const Icon(Icons.route_outlined),
        title: const Text('GPX 내보내기'),
        onTap: () => previewOnly('GPX 파일 저장'),
      ),
    ),
    Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_upload_outlined),
        title: const Text('백업과 복원'),
        onTap: () => previewOnly('iOS 파일 공유와 복원'),
      ),
    ),
    const Padding(
      padding: EdgeInsets.only(top: 16),
      child: Text(
        '미리보기 0.4.0 · 운영 앱은 Flutter iOS/Android로 빌드됩니다.',
        textAlign: TextAlign.center,
      ),
    ),
  ]);
}

class _Metric extends StatelessWidget {
  final String label, value;
  const _Metric(this.label, this.value);
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}

class PreviewMapPainter extends CustomPainter {
  final int selectedPlace;
  const PreviewMapPainter({this.selectedPlace = -1});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFB9D996), BlendMode.src);
    final pixel = Paint()..color = const Color(0x1A205C40);
    for (var x = 0.0; x < size.width; x += 12) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), pixel);
    }
    for (var y = 0.0; y < size.height; y += 12) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), pixel);
    }
    final water = Paint()..color = const Color(0xFF8FC5D8);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .72, size.width, size.height * .28),
      water,
    );
    final road = Paint()
      ..color = const Color(0xFFF7E2AF)
      ..strokeWidth = 28
      ..style = PaintingStyle.stroke;
    final route = Paint()
      ..color = const Color(0xFF2F7452)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .08, size.height * .75)
      ..cubicTo(
        size.width * .28,
        size.height * .25,
        size.width * .58,
        size.height * .9,
        size.width * .9,
        size.height * .22,
      );
    canvas.drawPath(path, road);
    canvas.drawPath(path, route);
    final places = [const Offset(.28, .32), const Offset(.72, .27)];
    for (var i = 0; i < places.length; i++) {
      final center = Offset(
        size.width * places[i].dx,
        size.height * places[i].dy,
      );
      final marker = Paint()
        ..color = i == selectedPlace
            ? const Color(0xFFFFD66B)
            : const Color(0xFFFFF4D8);
      final markerBorder = Paint()
        ..color = forest
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRect(
        Rect.fromCenter(center: center, width: 44, height: 44),
        marker,
      );
      canvas.drawRect(
        Rect.fromCenter(center: center, width: 44, height: 44),
        markerBorder,
      );
      final icon = TextPainter(
        text: TextSpan(
          text: i == 0 ? '🌳' : '🐾',
          style: const TextStyle(fontSize: 24),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      icon.paint(canvas, center - Offset(icon.width / 2, icon.height / 2));
    }
    canvas.save();
    canvas.translate(size.width * .08, size.height * .68);
    final dogDark = Paint()..color = const Color(0xFF3D2B22);
    final dogFur = Paint()..color = const Color(0xFFC77A43);
    canvas.drawRect(const Rect.fromLTWH(0, 6, 34, 28), dogDark);
    canvas.drawRect(const Rect.fromLTWH(6, 3, 22, 26), dogFur);
    canvas.drawRect(const Rect.fromLTWH(9, 11, 4, 4), dogDark);
    canvas.drawRect(const Rect.fromLTWH(21, 11, 4, 4), dogDark);
    canvas.drawRect(const Rect.fromLTWH(15, 19, 5, 4), dogDark);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PreviewMapPainter oldDelegate) =>
      oldDelegate.selectedPlace != selectedPlace;
}
