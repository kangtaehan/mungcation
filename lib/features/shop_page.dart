import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../models/catalog.dart';
import '../services/app_controller.dart';
import '../widgets/pet_room.dart';
import 'room_editor.dart';

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
