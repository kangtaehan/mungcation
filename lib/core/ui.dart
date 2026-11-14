import 'package:flutter/material.dart';

const forest = Color(0xFF205C40),
    beige = Color(0xFFF5EBDD),
    ink = Color(0xFF252525);
void feedback(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Future<bool> saveAction(
  BuildContext context,
  Future<bool> Function() action,
) async {
  try {
    return await action();
  } catch (_) {
    if (context.mounted)
      feedback(context, '저장하지 못했어요. 저장 공간을 확인하고 다시 시도해 주세요.');
    return false;
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = '확인',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
String dateLabel(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String durationLabel(int seconds) => '${seconds ~/ 60}분 ${seconds % 60}초';
