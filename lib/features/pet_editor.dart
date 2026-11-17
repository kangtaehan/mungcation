import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/ui.dart';
import '../models/app_data.dart';
import '../services/app_controller.dart';
import '../services/media_store.dart';
import '../widgets/pet_room.dart';
import '../widgets/pet_photo.dart';

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
              onPressed: working || kIsWeb
                  ? null
                  : () => pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_outlined),
              label: const Text('갤러리'),
            ),
            OutlinedButton.icon(
              onPressed: working || kIsWeb
                  ? null
                  : () => pick(ImageSource.camera),
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
            onPressed: working || kIsWeb ? null : pixelate,
            child: const Text('내 강아지 픽셀 사진 만들기'),
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
          kIsWeb
              ? '사진 선택·촬영·픽셀 변환은 모바일 앱에서 이용해 주세요.'
              : '사진 중앙을 정사각형으로 맞춘 뒤 색상과 윤곽을 픽셀 스타일로 바꿔요. 변환은 기기 안에서만 처리되며 결과는 방의 액자에 표시돼요.',
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
