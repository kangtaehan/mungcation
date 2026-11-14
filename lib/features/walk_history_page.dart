import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../services/app_controller.dart';
import '../services/walk_statistics.dart';
import 'history_page.dart';

enum HistoryPeriod { week, month, all }

class WalkHistoryPage extends StatefulWidget {
  final AppController controller;
  const WalkHistoryPage({super.key, required this.controller});
  @override
  State<WalkHistoryPage> createState() => _WalkHistoryPageState();
}

class _WalkHistoryPageState extends State<WalkHistoryPage> {
  HistoryPeriod period = HistoryPeriod.week;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selectedDay;
  void changeMonth(int offset) => setState(() {
    month = DateTime(month.year, month.month + offset);
    selectedDay = null;
    period = HistoryPeriod.month;
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('산책 통계와 달력')),
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final now = DateTime.now(),
            today = localDay(now),
            all = WalkStatistics(widget.controller.data.realWalks);
        final stats = selectedDay != null
            ? all.onDay(selectedDay!)
            : switch (period) {
                HistoryPeriod.week => all.between(
                  DateTime(today.year, today.month, today.day - 6),
                  DateTime(today.year, today.month, today.day + 1),
                ),
                HistoryPeriod.month => all.between(
                  month,
                  DateTime(month.year, month.month + 1),
                ),
                HistoryPeriod.all => all,
              };
        final days = all.recentDays(now, 7);
        final maxMeters = math.max(
          1.0,
          days.fold<double>(0, (a, b) => math.max(a, b.meters)),
        );
        final monthDays = DateTime(month.year, month.month + 1, 0).day,
            leading = month.weekday - 1;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<HistoryPeriod>(
              segments: const [
                ButtonSegment(value: HistoryPeriod.week, label: Text('최근 7일')),
                ButtonSegment(value: HistoryPeriod.month, label: Text('월별')),
                ButtonSegment(value: HistoryPeriod.all, label: Text('전체')),
              ],
              selected: {period},
              onSelectionChanged: (v) => setState(() {
                period = v.first;
                selectedDay = null;
              }),
            ),
            const SizedBox(height: 16),
            Card(
              color: beige,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _Metric('산책 횟수', '${stats.count}회'),
                    _Metric(
                      '산책 거리',
                      '${(stats.meters / 1000).toStringAsFixed(2)} km',
                    ),
                    _Metric('산책 시간', durationLabel(stats.seconds)),
                    _Metric('활동한 날', '${stats.activeDays}일'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '최근 7일 산책 거리',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Semantics(
              label:
                  '최근 7일 산책 거리. ${days.map((d) => '${d.day.month}월 ${d.day.day}일 ${d.meters.round()}미터').join(', ')}',
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final day in days)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              FittedBox(
                                child: Text(
                                  '${(day.meters / 1000).toStringAsFixed(1)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 18,
                                height: day.meters == 0
                                    ? 3
                                    : math.max(5, 85 * day.meters / maxMeters),
                                decoration: BoxDecoration(
                                  color: day.meters == 0
                                      ? const Color(0xFFD4D8CC)
                                      : forest,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${day.day.day}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                IconButton(
                  tooltip: '이전 달',
                  onPressed: () => changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${month.year}년 ${month.month}월',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '다음 달',
                  onPressed: month.isBefore(DateTime(now.year, now.month))
                      ? () => changeMonth(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: [
                for (final day in ['월', '화', '수', '목', '금', '토', '일'])
                  Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ((leading + monthDays + 6) ~/ 7) * 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 44,
              ),
              itemBuilder: (context, index) {
                final number = index - leading + 1;
                if (number < 1 || number > monthDays)
                  return const SizedBox.shrink();
                final date = DateTime(month.year, month.month, number),
                    active = all.onDay(date).count > 0,
                    selected = selectedDay == date;
                return Semantics(
                  label:
                      '${month.month}월 $number일, 산책 ${all.onDay(date).count}회',
                  selected: selected,
                  button: true,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Material(
                      color: selected
                          ? forest
                          : active
                          ? const Color(0xFFE8F0E7)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(
                          () => selectedDay = selected ? null : date,
                        ),
                        child: Center(
                          child: Text(
                            '$number',
                            style: TextStyle(
                              color: selected ? Colors.white : ink,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDay == null
                        ? '기간 내 산책 기록'
                        : '${selectedDay!.month}월 ${selectedDay!.day}일 기록',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (selectedDay != null)
                  TextButton(
                    onPressed: () => setState(() => selectedDay = null),
                    child: const Text('날짜 선택 해제'),
                  ),
              ],
            ),
            if (stats.records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('선택한 기간에 산책 기록이 없어요.'),
              ),
            for (final record in stats.records)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.pets, color: forest),
                title: Text(
                  '${(record.meters / 1000).toStringAsFixed(2)} km · ${durationLabel(record.seconds)}',
                ),
                subtitle: Text(dateLabel(record.startedAt.toLocal())),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => WalkResultPage(
                      record: record,
                      controller: widget.controller,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _Metric extends StatelessWidget {
  final String title, value;
  const _Metric(this.title, this.value);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ],
  );
}
