import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/ui.dart';
import '../services/app_controller.dart';
import '../services/backup_service.dart';
import '../services/walk_session.dart';

class DataToolsPage extends StatefulWidget {
  final AppController controller;
  final WalkSession session;
  final BackupService? backup;
  const DataToolsPage({
    super.key,
    required this.controller,
    required this.session,
    this.backup,
  });
  @override
  State<DataToolsPage> createState() => _DataToolsPageState();
}

class _DataToolsPageState extends State<DataToolsPage> {
  late final BackupService backup = widget.backup ?? BackupService();
  bool working = false;
  String? error;
  Future<void> run(Future<void> Function() action) async {
    if (working) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted)
        setState(
          () => error = e is FormatException
              ? e.message
              : e is PlatformException
              ? (e.message ?? '파일 작업을 완료하지 못했어요.')
              : '파일 작업을 완료하지 못했어요. 저장 공간과 파일을 확인해 주세요.',
        );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> export() async {
    final approved = await confirm(
      context,
      '백업 파일을 만들까요?',
      '프로필·사진·포인트·즐겨찾기와 완료된 산책 경로가 포함돼요. 암호화되지 않은 파일이므로 안전한 위치에 보관해 주세요.',
      action: '파일 만들기',
    );
    if (!approved || !mounted) return;
    if (await backup.shareBackup(widget.controller.data) && mounted)
      feedback(context, '백업 내보내기를 완료했어요.');
  }

  Future<void> restore() async {
    final bytes = await backup.transfer.pickBackup();
    if (bytes == null || !mounted) return;
    final preview = backup.decode(bytes), data = preview.data;
    final approved = await confirm(
      context,
      '이 백업으로 교체할까요?',
      '백업 날짜: ${dateLabel(preview.createdAt.toLocal())}\n반려견: ${data.pet!.name}\n산책 ${data.realWalks.length}회 · 즐겨찾기 ${data.savedPlaces.length}곳\n포인트 ${data.coins}P · 사진 ${preview.media.length}개\n\n현재 기기의 데이터를 합치지 않고 이 백업으로 교체해요. 잠금 화면 위치 기록 설정은 꺼진 상태로 복원돼요.',
      action: '백업으로 교체',
    );
    if (!approved || !mounted) return;
    await backup.restore(preview, widget.controller);
    if (mounted) feedback(context, '백업을 복원했어요.');
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !working,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('백업과 복원'),
        automaticallyImplyLeading: !working,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.controller, widget.session]),
        builder: (context, _) {
          final blocked =
              working || widget.controller.busy || widget.session.hasWalk;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.inventory_2_outlined, size: 44, color: forest),
              const SizedBox(height: 16),
              Text(
                '내 기록을 파일로 보관해요',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                '프로필·사진·포인트·꾸미기·즐겨찾기·완료된 산책 기록을 하나의 파일에 담아요. 계정이나 클라우드 자동 동기화는 사용하지 않아요.',
              ),
              const SizedBox(height: 16),
              if (widget.session.hasWalk)
                const Text(
                  '진행 중인 산책을 종료하거나 버린 뒤 백업·복원을 이용해 주세요.',
                  style: TextStyle(color: Colors.brown),
                ),
              if (working)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.brown),
                  ),
                ),
              FilledButton.icon(
                onPressed: blocked || widget.controller.error != null
                    ? null
                    : () => run(export),
                icon: const Icon(Icons.ios_share),
                label: const Text('백업 파일 내보내기'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: blocked ? null : () => run(restore),
                icon: const Icon(Icons.restore),
                label: const Text('백업 파일에서 복원'),
              ),
              const SizedBox(height: 24),
              const Text(
                '파일은 최대 32MB까지 지원해요. 복원 전에 파일 형식·사진·기록을 검사하며, 저장에 실패하면 현재 데이터는 유지돼요. 파일에 포함된 사진과 위치 정보는 암호화되지 않아요. 외부 앱에 공유하면 해당 앱의 보관 방식이 적용돼요.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          );
        },
      ),
    ),
  );
}
