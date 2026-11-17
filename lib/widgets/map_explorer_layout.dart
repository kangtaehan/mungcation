import 'package:flutter/material.dart';
import '../core/ui.dart';

/// Space covered by the mobile information sheet, for visible map controls.
class MapSheetInset extends InheritedWidget {
  final double bottom;
  const MapSheetInset({super.key, required this.bottom, required super.child});
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MapSheetInset>()?.bottom ?? 0;
  @override
  bool updateShouldNotify(MapSheetInset oldWidget) =>
      oldWidget.bottom != bottom;
}

/// A large map with a compact search surface and independently scrollable details.
class MapExplorerLayout extends StatefulWidget {
  final Widget map, search, filters;
  final List<Widget> children;
  const MapExplorerLayout({
    super.key,
    required this.map,
    required this.search,
    required this.filters,
    required this.children,
  });

  @override
  State<MapExplorerLayout> createState() => _MapExplorerLayoutState();
}

class _MapExplorerLayoutState extends State<MapExplorerLayout> {
  final sheet = DraggableScrollableController();
  final desktopScroll = ScrollController();
  double sheetFraction = .38;

  @override
  void initState() {
    super.initState();
    sheet.addListener(updateInset);
  }

  void updateInset() {
    if (sheet.isAttached && sheet.size != sheetFraction)
      setState(() => sheetFraction = sheet.size);
  }

  @override
  void dispose() {
    sheet.dispose();
    desktopScroll.dispose();
    super.dispose();
  }

  Widget details(ScrollController controller, {bool mobile = false}) =>
      ListView(
        key: const ValueKey('walk-details-list'),
        controller: controller,
        padding: EdgeInsets.fromLTRB(20, mobile ? 0 : 12, 20, 28),
        children: [
          if (mobile)
            Center(
              child: IconButton(
                tooltip: '산책 정보 펼치기',
                onPressed: () {
                  if (sheet.isAttached) {
                    sheet.animateTo(
                      .9,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                icon: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hairline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ...widget.children,
        ],
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 900) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 360,
              child: ColoredBox(
                color: paper,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: widget.search,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: widget.filters,
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: details(desktopScroll)),
                  ],
                ),
              ),
            ),
            Expanded(child: widget.map),
          ],
        );
      }
      return Stack(
        children: [
          Positioned.fill(
            child: MapSheetInset(
              bottom: constraints.maxHeight * sheetFraction,
              child: widget.map,
            ),
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.search,
                const SizedBox(height: 10),
                widget.filters,
              ],
            ),
          ),
          DraggableScrollableSheet(
            controller: sheet,
            initialChildSize: .38,
            minChildSize: .18,
            maxChildSize: .9,
            snap: true,
            snapSizes: const [.18, .38, .9],
            shouldCloseOnMinExtent: false,
            builder: (context, scroll) => DecoratedBox(
              decoration: const BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x160D2917),
                    blurRadius: 24,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: details(scroll, mobile: true),
              ),
            ),
          ),
        ],
      );
    },
  );
}
