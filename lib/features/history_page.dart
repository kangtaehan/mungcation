import '../services/backup_service.dart';
import 'walk_history_page.dart';
import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../models/walk_data.dart';
import '../services/app_controller.dart';
import '../services/walk_session.dart';
import '../widgets/walk_map.dart';

class WalkResultPage extends StatelessWidget {
  final WalkRecord record;
  final AppController controller;
  const WalkResultPage({
    super.key,
    required this.record,
    required this.controller,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('산책 기록')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          dateLabel(record.startedAt),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: WalkMap(
              samples: record.samples,
              current: record.samples.lastOrNull,
              fit: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            Text(
              '${(record.meters / 1000).toStringAsFixed(2)} km',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(durationLabel(record.seconds)),
            Text('+${record.points} P · +${record.xp} 경험치'),
          ],
        ),
        const SizedBox(height: 16),
        WalkExportButton(
          record: record,
          petName: controller.data.pet?.name ?? '강아지',
        ),
        const SizedBox(height: 16),
        const Text('방문 인증', style: TextStyle(fontWeight: FontWeight.bold)),
        if (record.visits.isEmpty) const Text('보상을 받은 방문 장소가 없어요.'),
        for (final visit in record.visits)
          ListTile(
            leading: const Icon(Icons.park),
            title: Text(visit.name),
            subtitle: Text(dateLabel(visit.time)),
            trailing: Text('+${visit.points} P'),
          ),
        const SizedBox(height: 12),
        const Text(
          '100m 이상·1분 이상 기록된 산책에 기본 20P와 경험치를 제공해요. 방문 보상은 같은 공원에서 하루 한 번, 전체 보상은 하루 120P까지예요. 무리하지 않고 반려견 컨디션에 맞춰 걸어 주세요.\n위치 오차와 일시정지 구간은 거리에서 제외될 수 있어요. 포인트는 앱 안에서만 사용해요.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () async {
            if (!await confirm(
                  context,
                  '기록을 삭제할까요?',
                  '이 산책의 시간·거리·위치 경로가 기기에서 삭제돼요. 이미 받은 포인트와 경험치, 중복 보상 확인 정보는 유지돼요.',
                  action: '삭제',
                ) ||
                !context.mounted)
              return;
            if (await saveAction(
                  context,
                  () => controller.deleteWalk(record.id),
                ) &&
                context.mounted)
              Navigator.pop(context);
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('이 산책 기록 삭제'),
        ),
      ],
    ),
  );
}

class HistorySection extends StatelessWidget {
  final AppController controller;
  final WalkSession session;
  const HistorySection({
    super.key,
    required this.controller,
    required this.session,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '산책 기록',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      TextButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => WalkHistoryPage(controller: controller),
          ),
        ),
        icon: const Icon(Icons.calendar_month_outlined),
        label: const Text('전체 기록 · 통계 · 달력'),
      ),
      if (controller.data.realWalks.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('아직 산책 기록이 없어요. 첫 산책을 시작해 보세요.'),
        ),
      for (final record in controller.data.realWalks.take(3))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.pets, color: forest),
          title: Text(
            '${(record.meters / 1000).toStringAsFixed(2)} km · ${durationLabel(record.seconds)}',
          ),
          subtitle: Text(dateLabel(record.startedAt)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  WalkResultPage(record: record, controller: controller),
            ),
          ),
        ),
      if (controller.data.realWalks.isNotEmpty ||
          controller.data.rewardedPlaces.isNotEmpty)
        TextButton(
          onPressed: session.hasWalk
              ? null
              : () async {
                  if (!await confirm(
                        context,
                        '위치 기록을 모두 삭제할까요?',
                        '저장된 산책 경로·기록과 방문 확인용 장소 식별자를 모두 삭제해요. 포인트·구매·경험치·즐겨찾기와 당일 보상 총량은 유지돼요.',
                        action: '모두 삭제',
                      ) ||
                      !context.mounted)
                    return;
                  await saveAction(context, controller.deleteAllLocationData);
                },
          child: const Text('전체 산책·위치 기록 삭제'),
        ),
      if (controller.data.walks.isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('이전 버전의 데모 기록'),
          children: [
            for (final demo in controller.data.walks)
              ListTile(
                title: Text(
                  '${dateLabel(demo.date)} · ${durationLabel(demo.seconds)}',
                ),
                subtitle: const Text('GPS 없는 데모 · 실제 산책이 아니에요.'),
              ),
          ],
        ),
    ],
  );
}

class WalkExportButton extends StatefulWidget {
  final WalkRecord record;
  final String petName;
  final BackupService? backup;
  const WalkExportButton({
    super.key,
    required this.record,
    required this.petName,
    this.backup,
  });
  @override
  State<WalkExportButton> createState() => _WalkExportButtonState();
}

class _WalkExportButtonState extends State<WalkExportButton> {
  bool working = false;
  @override
  Widget build(BuildContext context) {
    if (widget.record.samples.isEmpty)
      return const Text(
        'GPS 경로가 없어 GPX로 내보낼 수 없어요.',
        style: TextStyle(color: Colors.black54),
      );
    return OutlinedButton.icon(
      onPressed: working
          ? null
          : () async {
              if (!await confirm(
                    context,
                    '산책 경로를 내보낼까요?',
                    'GPX 파일에 정확한 이동 경로와 시각이 포함돼요. 파일 앱에 저장하거나 원하는 앱으로 공유할 수 있어요.',
                    action: 'GPX 만들기',
                  ) ||
                  !mounted)
                return;
              setState(() => working = true);
              try {
                final shared = await (widget.backup ?? BackupService())
                    .shareWalk(widget.record, widget.petName);
                if (shared && context.mounted)
                  feedback(context, '산책 경로를 내보냈어요.');
              } catch (_) {
                if (context.mounted)
                  feedback(context, 'GPX 파일을 내보내지 못했어요. 다시 시도해 주세요.');
              } finally {
                if (mounted) setState(() => working = false);
              }
            },
      icon: const Icon(Icons.ios_share),
      label: Text(working ? '내보내는 중…' : '산책 경로 GPX 내보내기'),
    );
  }
}
