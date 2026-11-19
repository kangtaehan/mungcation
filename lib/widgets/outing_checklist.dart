import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../models/saved_place.dart';
import '../models/walk_data.dart';
import '../services/app_controller.dart';

class OutingChecklist extends StatefulWidget {
  final AppController controller;
  final PlaceInfo place;
  const OutingChecklist({
    super.key,
    required this.controller,
    required this.place,
  });
  @override
  State<OutingChecklist> createState() => _OutingChecklistState();
}

class _OutingChecklistState extends State<OutingChecklist> {
  late final Set<String> checked;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final saved = widget.controller.data.savedPlaces[widget.place.id];
    checked = saved?.preparedOn(DateTime.now()) == true
        ? {...saved!.preparation}
        : {};
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.controller.data.savedPlaces[widget.place.id];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '외출 준비 ${checked.length}/${SavedPlace.preparationItems.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('오늘 챙긴 준비물과 입장 조건을 직접 확인해 주세요.'),
            if (saved?.preparedAt != null)
              Text(
                '최근 저장: ${dateLabel(saved!.preparedAt!.toLocal())}',
                style: const TextStyle(fontSize: 12, color: mutedInk),
              ),
            if (saved?.preparedAt != null && !saved!.preparedOn(DateTime.now()))
              const Text(
                '이전 외출 기록이에요. 오늘 준비물을 다시 확인해 주세요.',
                style: TextStyle(color: forest),
              ),
            for (final item in SavedPlace.preparationItems.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.value),
                value: checked.contains(item.key),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: saving
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          checked.add(item.key);
                        } else {
                          checked.remove(item.key);
                        }
                      }),
              ),
            const Text(
              '개인 준비 기록이며 시설의 입장 허용이나 경로 안전을 뜻하지 않아요.',
              style: TextStyle(fontSize: 12, color: mutedInk),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: saving || widget.controller.busy
                  ? null
                  : () async {
                      setState(() => saving = true);
                      final saved = await saveAction(
                        context,
                        () => widget.controller.savePlacePreparation(
                          widget.place,
                          checked,
                        ),
                      );
                      if (!mounted) return;
                      setState(() => saving = false);
                      if (saved) feedback(context, '이 장소의 외출 준비 상태를 저장했어요.');
                    },
              child: Text(saving ? '저장 중…' : '즐겨찾기에 준비 상태 저장'),
            ),
            TextButton(
              onPressed: saving ? null : () => setState(checked.clear),
              child: const Text('준비 항목 초기화'),
            ),
          ],
        ),
      ),
    );
  }
}
