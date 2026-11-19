import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../models/pet_admission.dart';
import '../services/source_link.dart';

class PetAdmissionPanel extends StatelessWidget {
  final PetAdmission? policy;
  final Future<void> Function(String)? onOpenSource;
  const PetAdmissionPanel({super.key, this.policy, this.onOpenSource});
  static String day(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  Widget fact(
    String title,
    String value, {
    String missing = '미확인 · 공개된 규정이 없어요.',
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: mutedInk,
          ),
        ),
        const SizedBox(height: 4),
        Text(value.isEmpty ? missing : value),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final value = policy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pets_outlined, color: forest, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '반려동물 입장 안내',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: value?.isAllowed == true ? mist : beige,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                value?.label ?? '동반 여부 미확인',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (value == null || !value.hasEvidence) ...[
              const SizedBox(height: 12),
              const Text(
                '유모차·캐리어 필요 여부 미확인 · 허용 구역, 크기 제한, 대여 여부를 시설에 확인해 주세요.',
              ),
            ] else ...[
              if (value.freshnessNotice(DateTime.now()) case final notice?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    notice,
                    style: const TextStyle(
                      color: forest,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (value.referenceDate != null)
                Text(
                  '자료 기준일: ${day(value.referenceDate!)}',
                  style: const TextStyle(fontSize: 12, color: mutedInk),
                ),
              if (value.checkedAt != null)
                Text(
                  '원문 확인·수집일: ${day(value.checkedAt!.toLocal())}',
                  style: const TextStyle(fontSize: 12, color: mutedInk),
                ),
              fact('입장 규정·준비물', value.conditions),
              fact(
                '유모차·캐리어',
                value.transportRule,
                missing: '필요 여부 미확인 · 원문에 이동수단 규정이 없어요.',
              ),
              fact('동반 가능한 구역', value.areaRule),
              fact('크기·몸무게 제한', value.sizeRule),
              fact('이동장·유모차 대여', value.rentalRule),
              fact('동반 추가 요금', value.fees),
              const SizedBox(height: 16),
              const Divider(),
              Text(
                '출처: ${value.sourceName}',
                style: const TextStyle(fontSize: 12, color: mutedInk),
              ),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('원문 보기'),
                onPressed: () async {
                  try {
                    await (onOpenSource ?? openSourceLink)(value.sourceUrl);
                  } catch (_) {
                    if (context.mounted)
                      feedback(context, '원문을 열지 못했어요. 잠시 후 다시 시도해 주세요.');
                  }
                },
              ),
              const Text(
                '자료 작성 이후 정책이 바뀔 수 있어요. 방문 전 해당 지점의 최신 규정과 출입 가능 구역을 다시 확인해 주세요.',
                style: TextStyle(fontSize: 12, color: mutedInk),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
