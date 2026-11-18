import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/ui.dart';
import '../models/saved_place.dart';
import '../models/walk_data.dart';
import '../services/app_controller.dart';
import '../services/map_service.dart';
import '../widgets/pet_admission_panel.dart';

class PlaceDetails extends StatelessWidget {
  final PlaceInfo place;
  final MapService maps;
  final AppController controller;
  final VoidCallback? onRoute;
  const PlaceDetails({
    super.key,
    required this.place,
    required this.maps,
    required this.controller,
    this.onRoute,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final saved = controller.data.savedPlaces[place.id];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                place.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(place.address.isEmpty ? '주소 정보 없음' : place.address),
              Text('전화: ${place.phone.isEmpty ? '정보 없음' : place.phone}'),
              Text(
                '영업시간: ${place.admission?.openingHours.isNotEmpty == true ? '${place.admission!.openingHours} (자료 기준)' : '매장 확인 필요'}',
              ),
              const Divider(),
              PetAdmissionPanel(policy: place.admission),
              const SizedBox(height: 12),
              Text(
                '장소 출처: ${place.source}\n검색 시각: ${dateLabel(place.fetchedAt.toLocal())}',
              ),
              if (place.referenceDate case final reference?)
                Text(
                  '공원 데이터 기준일: ${reference.year}-${reference.month.toString().padLeft(2, '0')}-${reference.day.toString().padLeft(2, '0')}',
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: controller.busy
                        ? null
                        : () async {
                            if (saved != null &&
                                (saved.note.isNotEmpty ||
                                    saved.access != PetAccess.unknown) &&
                                !await confirm(
                                  context,
                                  '즐겨찾기를 해제할까요?',
                                  '이 장소의 개인 메모도 함께 삭제돼요.',
                                  action: '해제',
                                ))
                              return;
                            if (context.mounted)
                              await saveAction(
                                context,
                                () => controller.toggleSavedPlace(place),
                              );
                          },
                    icon: Icon(saved == null ? Icons.star_border : Icons.star),
                    label: Text(saved == null ? '즐겨찾기 저장' : '즐겨찾기 해제'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (context) => PlaceNoteEditor(
                              place: place,
                              controller: controller,
                            ),
                          ),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('내 동반 조건 메모'),
                  ),
                ],
              ),
              if (saved?.notedAt != null)
                Card(
                  elevation: 0,
                  color: beige,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '내가 기록한 정보 · 공식 확인 아님',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(saved!.access.label),
                        if (saved.note.isNotEmpty) Text(saved.note),
                        Text(
                          '작성: ${dateLabel(saved.notedAt!.toLocal())}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (place.rewardEligible)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    '공원 방문 보상은 정확한 GPS와 체류 시간으로 자동 인증해요. 지도 핀에 접근하기 위해 위험하거나 출입이 제한된 곳에 들어가지 마세요.',
                  ),
                ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onRoute != null)
                    FilledButton(
                      onPressed: onRoute,
                      child: const Text('여기까지 도보 경로'),
                    ),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await maps.openPlace(place);
                      } catch (_) {
                        if (context.mounted)
                          feedback(context, '지도 앱을 열지 못했어요.');
                      }
                    },
                    child: const Text('지도 앱에서 확인'),
                  ),
                  if (place.phone.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await Clipboard.setData(
                            ClipboardData(text: place.phone),
                          );
                          if (context.mounted)
                            feedback(context, '전화번호를 복사했어요.');
                        } catch (_) {
                          if (context.mounted)
                            feedback(context, '전화번호를 복사하지 못했어요.');
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('전화번호 복사'),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

class PlaceNoteEditor extends StatefulWidget {
  final PlaceInfo place;
  final AppController controller;
  const PlaceNoteEditor({
    super.key,
    required this.place,
    required this.controller,
  });
  @override
  State<PlaceNoteEditor> createState() => _PlaceNoteEditorState();
}

class _PlaceNoteEditorState extends State<PlaceNoteEditor> {
  late final TextEditingController note;
  late PetAccess access;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final saved = widget.controller.data.savedPlaces[widget.place.id];
    note = TextEditingController(text: saved?.note ?? '');
    access = saved?.access ?? PetAccess.unknown;
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '내 동반 조건 메모',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(widget.place.displayName),
            const SizedBox(height: 12),
            const Text(
              '이 기기에 저장하는 개인 메모예요. 다른 사용자에게 공개하거나 공식 매장 정보로 표시하지 않아요. 저장하면 즐겨찾기에 추가돼요.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PetAccess>(
              initialValue: access,
              decoration: const InputDecoration(labelText: '내가 기록할 동반 여부'),
              items: [
                for (final value in PetAccess.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: saving ? null : (v) => setState(() => access = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: note,
              maxLength: 2000,
              minLines: 3,
              maxLines: 8,
              enabled: !saving,
              decoration: const InputDecoration(
                labelText: '확인한 조건과 출처 메모',
                hintText: '예: 전화 문의 날짜, 실내·실외, 목줄·케이지, 대여·몸무게 제한, 메뉴 등',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setState(() => saving = true);
                      final saved = await saveAction(
                        context,
                        () => widget.controller.savePlaceNote(
                          widget.place,
                          note.text,
                          access,
                        ),
                      );
                      if (!mounted) return;
                      if (saved)
                        Navigator.pop(context);
                      else
                        setState(() => saving = false);
                    },
              child: Text(saving ? '저장 중…' : '즐겨찾기와 메모 저장'),
            ),
          ],
        ),
      ),
    ),
  );
}
