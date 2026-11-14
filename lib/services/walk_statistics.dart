import '../models/walk_data.dart';

DateTime localDay(DateTime value) {
  final date = value.toLocal();
  return DateTime(date.year, date.month, date.day);
}

class DayActivity {
  final DateTime day;
  final int count, seconds, points;
  final double meters;
  const DayActivity(
    this.day,
    this.count,
    this.seconds,
    this.meters,
    this.points,
  );
}

class WalkStatistics {
  final List<WalkRecord> records;
  WalkStatistics(Iterable<WalkRecord> records)
    : records = List.unmodifiable(
        records.toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
      );
  int get count => records.length;
  int get seconds => records.fold(0, (sum, w) => sum + w.seconds);
  double get meters => records.fold(0, (sum, w) => sum + w.meters);
  int get points => records.fold(0, (sum, w) => sum + w.points);
  int get activeDays =>
      records.map((w) => localDay(w.startedAt)).toSet().length;
  WalkStatistics between(DateTime start, DateTime endExclusive) =>
      WalkStatistics(
        records.where(
          (w) =>
              !w.startedAt.isBefore(start) &&
              w.startedAt.isBefore(endExclusive),
        ),
      );
  WalkStatistics onDay(DateTime day) {
    final start = localDay(day);
    return between(start, DateTime(start.year, start.month, start.day + 1));
  }

  List<DayActivity> recentDays(DateTime now, int days) {
    if (days < 1 || days > 366) throw ArgumentError.value(days, 'days');
    final end = localDay(now);
    return List.generate(days, (i) {
      final day = DateTime(end.year, end.month, end.day - days + 1 + i),
          stats = onDay(day);
      return DayActivity(
        day,
        stats.count,
        stats.seconds,
        stats.meters,
        stats.points,
      );
    });
  }
}
