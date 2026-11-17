import 'package:flutter/material.dart';

const forest = Color(0xFF205C40),
    beige = Color(0xFFF5EBDD),
    ink = Color(0xFF252525);
const paper = Color(0xFFFFFEFB),
    canvas = Color(0xFFF6F8F5),
    mist = Color(0xFFEDF4EC),
    mutedInk = Color(0xFF657167),
    hairline = Color(0xFFE2E9E1);

ThemeData mungcationTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: forest,
      primary: forest,
      surface: paper,
    ),
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium!.copyWith(
        fontSize: 25,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -.6,
        color: ink,
      ),
      titleLarge: base.textTheme.titleLarge!.copyWith(
        fontSize: 20,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: base.textTheme.titleMedium!.copyWith(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyMedium: base.textTheme.bodyMedium!.copyWith(
        fontSize: 14,
        height: 1.5,
        color: ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: paper,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: hairline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: rounded,
        textStyle: base.textTheme.labelLarge!.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: rounded,
        side: const BorderSide(color: hairline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: mutedInk, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: forest, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: paper,
      selectedColor: mist,
      side: const BorderSide(color: hairline),
      shape: const StadiumBorder(),
      labelStyle: base.textTheme.labelLarge!.copyWith(
        fontSize: 13,
        color: forest,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    ),
    dividerTheme: const DividerThemeData(color: hairline, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      indicatorColor: mist,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? forest : mutedInk,
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

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
