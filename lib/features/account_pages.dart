import 'dart:io';
import 'package:flutter/foundation.dart';
import 'android_map_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/ui.dart';
import '../models/app_data.dart';
import '../models/catalog.dart';
import '../services/app_controller.dart';
import '../services/walk_session.dart';
import '../services/media_store.dart';
import '../widgets/pet_room.dart';
import '../widgets/pet_photo.dart';
import 'history_page.dart';

class ShopPage extends StatelessWidget {
  final AppController controller;
  const ShopPage({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final d = controller.data;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('꾸미기 상점', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '${d.coins} P · Lv.${d.level}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        PetRoom(
          equipped: d.equipped,
          equipment: d.equipment,
          name: d.pet!.name,
          character: d.pet!.character,
          pixelPhoto: d.pet!.pixelPhoto,
          furniture: d.furniture,
        ),
        const SizedBox(height: 12),
        const Text('모자·리본·선글라스·목걸이를 함께 착용할 수 있어요.'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in cosmetics)
                SizedBox(
                  width: (c.maxWidth - 12) / 2,
                  child: Card(
                    color: beige,
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            item.emoji,
                            style: const TextStyle(fontSize: 36),
                          ),
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            d.owned.contains(item.id)
                                ? '보유 중'
                                : '${item.price} P',
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed:
                                controller.busy ||
                                    (!d.owned.contains(item.id) &&
                                        d.level < item.minLevel)
                                ? null
                                : () => saveAction(context, () async {
                                    if (d.owned.contains(item.id))
                                      return controller.toggleEquipment(
                                        item.id,
                                      );
                                    if (d.coins < item.price) {
                                      feedback(context, '포인트가 부족해요.');
                                      return false;
                                    }
                                    return controller.purchase(
                                      item.id,
                                      item.name,
                                      item.price,
                                    );
                                  }),
                            child: Text(
                              (!d.owned.contains(item.id) &&
                                      d.level < item.minLevel)
                                  ? 'Lv.${item.minLevel} 해제'
                                  : d.equipment.contains(item.id)
                                  ? '해제'
                                  : d.owned.contains(item.id)
                                  ? '장착'
                                  : '구매 · 장착',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '방 소품',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        for (final item in furnitureCatalog)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CustomPaint(
              size: const Size(44, 44),
              painter: FurniturePainter(item.id),
            ),
            title: Text(item.name),
            subtitle: Text(
              d.owned.contains(item.id) ? '보유 중' : '${item.price} P',
            ),
            trailing: FilledButton.tonal(
              onPressed: controller.busy || d.owned.contains(item.id)
                  ? null
                  : () => saveAction(context, () async {
                      if (d.coins < item.price) {
                        feedback(context, '포인트가 부족해요.');
                        return false;
                      }
                      return controller.buyFurniture(item.id);
                    }),
              child: Text(d.owned.contains(item.id) ? '보유' : '구매'),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => RoomEditor(controller: controller),
            ),
          ),
          icon: const Icon(Icons.chair_outlined),
          label: const Text('내 방 배치하기'),
        ),
        const Text(
          '앱 포인트는 현금 가치가 없으며 구매한 소품은 이 기기에 저장돼요.',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class RoomEditor extends StatefulWidget {
  final AppController controller;
  const RoomEditor({super.key, required this.controller});
  @override
  State<RoomEditor> createState() => _RoomEditorState();
}

class _RoomEditorState extends State<RoomEditor> {
  late Map<String, List<double>> layout = {...widget.controller.data.furniture};
  bool saving = false;
  @override
  Widget build(BuildContext context) {
    final d = widget.controller.data;
    return Scaffold(
      appBar: AppBar(title: const Text('내 방 꾸미기')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('소품을 손가락으로 끌어 원하는 위치에 놓아 주세요.'),
          const SizedBox(height: 16),
          PetRoom(
            equipped: d.equipped,
            equipment: d.equipment,
            name: d.pet!.name,
            character: d.pet!.character,
            pixelPhoto: d.pet!.pixelPhoto,
            furniture: layout,
            onMove: (id, position) =>
                setState(() => layout = {...layout, id: position}),
          ),
          const SizedBox(height: 16),
          for (final item in furnitureCatalog.where(
            (e) => d.owned.contains(e.id),
          ))
            SwitchListTile(
              title: Text(item.name),
              value: layout.containsKey(item.id),
              onChanged: saving
                  ? null
                  : (v) => setState(() {
                      if (v) {
                        layout[item.id] = [.7, .65];
                      } else {
                        layout.remove(item.id);
                      }
                    }),
            ),
          if (!furnitureCatalog.any((e) => d.owned.contains(e.id)))
            const Text('상점에서 소품을 구매하면 배치할 수 있어요.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    final saved = await saveAction(
                      context,
                      () => widget.controller.update(
                        (data) => data.copyWith(furniture: layout),
                      ),
                    );
                    if (!mounted) return;
                    if (saved)
                      Navigator.pop(context);
                    else
                      setState(() => saving = false);
                  },
            child: Text(saving ? '저장 중…' : '배치 저장'),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final AppController controller;
  final WalkSession session;
  const ProfilePage({
    super.key,
    required this.controller,
    required this.session,
  });
  @override
  Widget build(BuildContext context) {
    final d = controller.data;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('마이', style: Theme.of(context).textTheme.headlineMedium),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: d.pet!.photo.isEmpty
              ? const Icon(Icons.pets)
              : SizedBox(
                  width: 48,
                  height: 48,
                  child: ClipOval(child: PetPhoto(d.pet!.photo)),
                ),
          title: Text(d.pet!.name),
          subtitle: Text(
            '${d.pet!.breed.isEmpty ? '견종 미등록' : d.pet!.breed} · ${d.pet!.size} · ${d.pet!.temperament}',
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('반려견 정보')),
                body: SafeArea(
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (_, _) =>
                        PetEditor(controller: controller, editing: true),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          'Lv.${d.level} · 경험치 ${d.xp % 100} / 100',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: (d.xp % 100) / 100),
        const SizedBox(height: 8),
        const Text(
          '산책을 마치면 경험치가 쌓여요. Lv.2에 왕관이 열려요. 하루 보상 한도 안에서만 경험치를 받을 수 있어요.',
        ),
        const SizedBox(height: 20),
        ListenableBuilder(
          listenable: session,
          builder: (context, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('화면을 잠가도 산책 기록'),
            subtitle: const Text('산책 중에만 백그라운드 위치를 사용해요. 꺼두면 앱을 벗어날 때 일시정지해요.'),
            value: d.backgroundLocation,
            onChanged: session.hasWalk || controller.busy
                ? null
                : (value) async {
                    if (value &&
                        !await confirm(
                          context,
                          '잠금 화면 산책 기록',
                          '산책 중 화면을 잠가도 위치를 기록할 수 있도록 기기의 백그라운드 위치 기능을 사용해요. 배터리 사용량이 늘 수 있으며 운영체제 상태에 따라 기록이 중단될 수 있어요.',
                          action: '사용하기',
                        ))
                      return;
                    if (context.mounted)
                      await saveAction(
                        context,
                        () => controller.update(
                          (data) => data.copyWith(backgroundLocation: value),
                        ),
                      );
                  },
          ),
        ),
        if (!kIsWeb && Platform.isAndroid)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.map_outlined),
            title: const Text('지도 서비스 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AndroidMapSettingsPage(),
              ),
            ),
          ),
        const Divider(),
        HistorySection(controller: controller, session: session),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('포인트 지갑 · ${d.coins} P'),
          subtitle: const Text('현금 가치 없는 앱 포인트'),
          children: [
            for (final e in d.wallet)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.title),
                subtitle: Text(dateLabel(e.date)),
                trailing: Text('${e.amount >= 0 ? '+' : ''}${e.amount} P'),
              ),
          ],
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: '멍케이션',
            applicationVersion: '0.4.0',
          ),
          child: const Text('오픈소스 라이선스'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class PetEditor extends StatefulWidget {
  final AppController controller;
  final bool editing;
  const PetEditor({super.key, required this.controller, this.editing = false});
  @override
  State<PetEditor> createState() => _PetEditorState();
}

class _PetEditorState extends State<PetEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, breed, age, weight;
  late String size, temperament, photo, pixelPhoto, character;
  bool working = false;
  bool committed = false;
  final Set<String> staged = {};
  @override
  void initState() {
    super.initState();
    final p = widget.controller.data.pet;
    name = TextEditingController(text: p?.name ?? '');
    breed = TextEditingController(text: p?.breed ?? '');
    age = TextEditingController(text: p == null ? '' : '${p.age}');
    weight = TextEditingController(
      text: p == null || p.weight == 0 ? '' : '${p.weight}',
    );
    size = p?.size ?? '소형견';
    temperament = p?.temperament ?? '보통';
    photo = p?.photo ?? '';
    pixelPhoto = p?.pixelPhoto ?? '';
    character = p?.character ?? 'original';
    if (!kIsWeb && Platform.isAndroid) {
      working = true;
      recoverPhoto();
    }
  }

  @override
  void dispose() {
    for (final c in [name, breed, age, weight]) {
      c.dispose();
    }
    if (!committed) {
      for (final file in staged) {
        MediaStore.instance.delete(file).catchError((Object _) {});
      }
    }
    super.dispose();
  }

  Future<void> recoverPhoto() async {
    try {
      final result = await MediaStore.instance.recoverLostPhoto();
      if (result != null) {
        if (!mounted) {
          await MediaStore.instance.delete(result);
          return;
        }
        staged.add(result);
        setState(() {
          photo = result;
          pixelPhoto = '';
        });
        feedback(context, '중단된 사진 선택을 복구했어요. 저장하면 프로필에 반영돼요.');
      }
    } catch (_) {
      if (mounted) feedback(context, '이전 사진 선택을 복구하지 못했어요. 사진을 다시 선택해 주세요.');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> pick(ImageSource source) async {
    setState(() => working = true);
    try {
      final result = await MediaStore.instance.pick(source);
      if (result != null) {
        if (!mounted) {
          await MediaStore.instance.delete(result);
          return;
        }
        staged.add(result);
        setState(() {
          photo = result;
          pixelPhoto = '';
        });
      }
    } catch (_) {
      if (mounted)
        feedback(context, '사진을 가져오지 못했어요. 기기의 사진·카메라 권한과 사용 가능 여부를 확인해 주세요.');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> pixelate() async {
    setState(() => working = true);
    try {
      final result = await MediaStore.instance.pixelate(photo);
      if (!mounted) {
        await MediaStore.instance.delete(result);
        return;
      }
      staged.add(result);
      setState(() => pixelPhoto = result);
    } catch (_) {
      if (mounted) feedback(context, '이 사진은 변환하지 못했어요. 다른 사진을 선택해 주세요.');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => working = true);
    final old = widget.controller.data.pet;
    final pet = PetProfile(
      name: name.text.trim(),
      breed: breed.text.trim(),
      age: int.tryParse(age.text) ?? 0,
      weight: double.tryParse(weight.text) ?? 0,
      size: size,
      temperament: temperament,
      photo: photo,
      pixelPhoto: pixelPhoto,
      character: character,
    );
    // Mark staged files retained before a successful commit can unmount onboarding.
    committed = true;
    final saved = await saveAction(
      context,
      () => widget.controller.update((d) => d.copyWith(pet: pet)),
    );
    if (saved) {
      for (final file in {
        ...staged,
        if (old != null) old.photo,
        if (old != null) old.pixelPhoto,
      }.where((f) => f.isNotEmpty && f != photo && f != pixelPhoto)) {
        try {
          await MediaStore.instance.delete(file);
        } catch (_) {}
      }
      if (widget.editing && mounted) Navigator.pop(context);
    } else {
      committed = false;
    }
    if (mounted) setState(() => working = false);
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.editing ? '반려견 정보' : '멍케이션에 오신 걸 환영해요',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text('함께 산책할 친구를 소개해 주세요.'),
        const SizedBox(height: 20),
        TextFormField(
          controller: name,
          maxLength: 20,
          decoration: const InputDecoration(labelText: '이름 (필수)'),
          validator: (v) =>
              v == null || v.trim().isEmpty ? '이름을 입력해 주세요.' : null,
        ),
        TextFormField(
          controller: breed,
          maxLength: 40,
          decoration: const InputDecoration(labelText: '견종 (선택)'),
        ),
        TextFormField(
          controller: age,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '나이 · 만 나이 (선택)'),
          validator: (v) =>
              v!.isEmpty ||
                  ((int.tryParse(v) ?? -1) >= 0 &&
                      (int.tryParse(v) ?? 100) <= 40)
              ? null
              : '0~40 사이 정수를 입력해 주세요.',
        ),
        TextFormField(
          controller: weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '몸무게 · kg (선택)'),
          validator: (v) =>
              v!.isEmpty ||
                  ((double.tryParse(v) ?? -1) > 0 &&
                      (double.tryParse(v) ?? 200) <= 150)
              ? null
              : '150kg 이하의 양수를 입력해 주세요.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: size,
          decoration: const InputDecoration(labelText: '크기'),
          items: [
            for (final s in ['소형견', '중형견', '대형견'])
              DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: working ? null : (v) => setState(() => size = v!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: temperament,
          decoration: const InputDecoration(labelText: '산책 성향'),
          items: [
            for (final s in ['느긋함', '보통', '활발함'])
              DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: working ? null : (v) => setState(() => temperament = v!),
        ),
        const SizedBox(height: 24),
        const Text(
          '반려견 사진',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (photo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(height: 150, child: PetPhoto(photo)),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: working ? null : () => pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_outlined),
              label: const Text('갤러리'),
            ),
            OutlinedButton.icon(
              onPressed: working ? null : () => pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('촬영'),
            ),
            if (photo.isNotEmpty)
              TextButton(
                onPressed: working
                    ? null
                    : () => setState(() {
                        photo = '';
                        pixelPhoto = '';
                      }),
                child: const Text('사진 삭제'),
              ),
          ],
        ),
        if (photo.isNotEmpty)
          OutlinedButton(
            onPressed: working ? null : pixelate,
            child: const Text('기기에서 픽셀 스타일로 변환'),
          ),
        if (pixelPhoto.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              height: 120,
              child: PetPhoto(pixelPhoto, pixel: true),
            ),
          ),
        const Text(
          '픽셀 필터는 사진의 해상도를 줄이는 기기 내 효과예요. AI 캐릭터 생성이 아니며, 변환한 사진은 방의 액자에 표시돼요.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        const Text(
          '강아지 캐릭터',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in {
              'original': '기존 강아지',
              'brown': '갈색 강아지',
              'cream': '크림 강아지',
              'black': '검정 강아지',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: character == entry.key,
                onSelected: working
                    ? null
                    : (_) => setState(() => character = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PetRoom(
          equipped: widget.controller.data.equipped,
          equipment: widget.controller.data.equipment,
          name: name.text.isEmpty ? '강아지' : name.text,
          character: character,
          pixelPhoto: pixelPhoto,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: working || widget.controller.busy ? null : save,
          child: Text(
            working
                ? '처리 중…'
                : widget.editing
                ? '저장'
                : '기본 캐릭터로 시작하기',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'AI 캐릭터 생성: 서버 미연결. 사진은 외부로 전송되지 않아요.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    ),
  );
}
