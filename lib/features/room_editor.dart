import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../models/catalog.dart';
import '../services/app_controller.dart';
import '../widgets/pet_room.dart';

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
