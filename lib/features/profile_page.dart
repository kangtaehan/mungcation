import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../services/app_controller.dart';
import '../services/walk_session.dart';
import '../widgets/pet_photo.dart';
import 'history_page.dart';
import 'data_tools_page.dart';
import 'android_map_settings_page.dart';
import 'pet_editor.dart';

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
            subtitle: Text(
              kIsWeb
                  ? '모바일 앱에서 이용할 수 있어요. 웹에서는 탭을 벗어나면 기록이 중단될 수 있어요.'
                  : '산책 중에만 백그라운드 위치를 사용해요. 꺼두면 앱을 벗어날 때 일시정지해요.',
            ),
            value: d.backgroundLocation,
            onChanged: kIsWeb || session.hasWalk || controller.busy
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
        if (kIsWeb || Platform.isAndroid || Platform.isIOS)
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
        if (!kIsWeb)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('백업과 복원'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    DataToolsPage(controller: controller, session: session),
              ),
            ),
          ),
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
