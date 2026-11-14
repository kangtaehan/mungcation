import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'pet_photo.dart';

class PetRoom extends StatefulWidget {
  final String equipped, name;
  final Set<String>? equipment;
  final Map<String, List<double>> furniture;
  final String character, pixelPhoto;
  final void Function(String, List<double>)? onMove;
  const PetRoom({
    super.key,
    required this.equipped,
    required this.name,
    this.equipment,
    this.furniture = const {},
    this.character = 'original',
    this.pixelPhoto = '',
    this.onMove,
  });
  @override
  State<PetRoom> createState() => _PetRoomState();
}

class _PetRoomState extends State<PetRoom> with SingleTickerProviderStateMixin {
  late final AnimationController reaction = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  @override
  void dispose() {
    reaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${widget.name} 쓰다듬기',
    child: GestureDetector(
      onTap: () => reaction.forward(from: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: AspectRatio(
          aspectRatio: 869 / 515,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.character == 'original')
                Image.asset(
                  'assets/images/pixel_room.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              if (widget.character != 'original')
                AnimatedBuilder(
                  animation: reaction,
                  builder: (context, _) => CustomPaint(
                    painter: PixelRoomPainter(
                      widget.character,
                      reaction.isAnimating ? reaction.value : 0,
                    ),
                  ),
                ),
              for (final id
                  in widget.equipment ??
                      (widget.equipped == 'none'
                          ? <String>{}
                          : {widget.equipped}))
                AnimatedBuilder(
                  animation: reaction,
                  builder: (context, _) => CustomPaint(
                    painter: AccessoryPainter(
                      id,
                      jump:
                          widget.character == 'original' ||
                              !reaction.isAnimating
                          ? 0
                          : math.sin(reaction.value * math.pi) * 20,
                    ),
                  ),
                ),
              if (widget.pixelPhoto.isNotEmpty)
                Align(
                  alignment: const Alignment(.73, -.6),
                  child: FractionallySizedBox(
                    widthFactor: .15,
                    heightFactor: .21,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFB88655),
                          width: 4,
                        ),
                      ),
                      child: PetPhoto(widget.pixelPhoto, pixel: true),
                    ),
                  ),
                ),
              LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    for (final entry in widget.furniture.entries)
                      Positioned(
                        left:
                            entry.value[0].clamp(0, .82) * constraints.maxWidth,
                        top:
                            entry.value[1].clamp(0, .75) *
                            constraints.maxHeight,
                        child: Semantics(
                          label: entry.key == 'plant'
                              ? '초록 화분'
                              : entry.key == 'bed'
                              ? '포근 침대'
                              : '놀이 공',
                          child: GestureDetector(
                            onPanUpdate: widget.onMove == null
                                ? null
                                : (details) => widget.onMove!(entry.key, [
                                    (entry.value[0] +
                                            details.delta.dx /
                                                constraints.maxWidth)
                                        .clamp(0, .82),
                                    (entry.value[1] +
                                            details.delta.dy /
                                                constraints.maxHeight)
                                        .clamp(0, .75),
                                  ]),
                            child: CustomPaint(
                              size: Size(
                                constraints.maxWidth * .18,
                                constraints.maxHeight * .25,
                              ),
                              painter: FurniturePainter(entry.key),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: reaction,
                builder: (context, _) => Align(
                  alignment: Alignment(0, -.5 - reaction.value * .35),
                  child: Opacity(
                    opacity: reaction.isAnimating ? 1 - reaction.value : 0,
                    child: Transform.scale(
                      scale: 1 + reaction.value * .6,
                      child: const Icon(
                        Icons.favorite,
                        color: Color(0xFFEA7979),
                        size: 38,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Separate transparent layer anchored to the original artwork's 869×515 coordinates.
class AccessoryPainter extends CustomPainter {
  final String item;
  final double jump;
  AccessoryPainter(this.item, {this.jump = 0});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 869, size.height / 515);
    canvas.translate(0, -jump);
    void block(double x, double y, double w, double h, Color c) =>
        canvas.drawRect(
          Rect.fromLTWH(x, y, w, h),
          Paint()
            ..color = c
            ..isAntiAlias = false,
        );
    const dark = Color(0xFF292B2E),
        pink = Color(0xFFE68A9D),
        gold = Color(0xFFE8B85B),
        green = Color(0xFF205C40);
    switch (item) {
      case 'cap':
        block(365, 156, 89, 24, dark);
        block(376, 130, 66, 28, dark);
        block(382, 136, 54, 27, green);
        block(371, 160, 108, 13, green);
        block(392, 142, 12, 6, const Color(0xFF7AAB80));
      case 'crown':
        block(369, 143, 86, 30, dark);
        block(376, 119, 14, 27, dark);
        block(405, 109, 14, 37, dark);
        block(435, 119, 14, 27, dark);
        block(376, 144, 72, 22, gold);
        block(382, 125, 8, 25, gold);
        block(411, 115, 8, 32, gold);
        block(435, 125, 8, 25, gold);
        block(405, 149, 10, 10, const Color(0xFFDC7373));
      case 'ribbon':
        block(453, 174, 23, 30, dark);
        block(481, 174, 23, 30, dark);
        block(459, 180, 17, 18, pink);
        block(481, 180, 17, 18, pink);
        block(475, 183, 10, 13, const Color(0xFFCA5577));
      case 'glasses':
        block(364, 202, 39, 28, dark);
        block(414, 202, 39, 28, dark);
        block(400, 208, 16, 7, dark);
        block(452, 202, 14, 6, dark);
        block(370, 208, 13, 5, const Color(0xFF97B6B4));
        block(420, 208, 13, 5, const Color(0xFF97B6B4));
      case 'necklace':
        block(374, 280, 83, 15, green);
        block(404, 292, 17, 17, dark);
        block(408, 294, 12, 12, gold);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AccessoryPainter old) =>
      old.item != item || old.jump != jump;
}

class PixelRoomPainter extends CustomPainter {
  final String style;
  final double frame;
  PixelRoomPainter(this.style, this.frame);
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 869, size.height / 515);
    void rect(double x, double y, double w, double h, Color color) =>
        c.drawRect(
          Rect.fromLTWH(x, y, w, h),
          Paint()
            ..color = color
            ..isAntiAlias = false,
        );
    const wall = Color(0xFFF5EBDD),
        floor = Color(0xFFD9AE82),
        dark = Color(0xFF3D3029);
    rect(0, 0, 869, 515, wall);
    rect(0, 340, 869, 175, floor);
    rect(0, 334, 869, 8, const Color(0xFFBD9267));
    for (var y = 365.0; y < 515; y += 38) {
      rect(0, y, 869, 3, const Color(0xFFCB9B6C));
    }
    rect(90, 240, 154, 110, const Color(0xFFBA895B));
    rect(102, 250, 130, 12, const Color(0xFFD9AD7E));
    rect(162, 280, 12, 8, dark);
    rect(650, 75, 125, 105, const Color(0xFFBD9267));
    rect(660, 85, 105, 85, const Color(0xFFE8F0E7));
    rect(670, 125, 85, 35, const Color(0xFF96AB87));
    rect(120, 200, 50, 42, const Color(0xFFC9956E));
    rect(140, 155, 12, 48, const Color(0xFF527D51));
    rect(120, 170, 28, 17, const Color(0xFF628A5E));
    rect(150, 160, 27, 17, const Color(0xFF628A5E));
    c.save();
    c.translate(0, -math.sin(frame * math.pi) * 20);
    final fur = style == 'cream'
        ? const Color(0xFFE3C59A)
        : style == 'black'
        ? const Color(0xFF59514D)
        : const Color(0xFFB47A4D);
    final light = style == 'black'
        ? const Color(0xFFD4C4AD)
        : const Color(0xFFF7E1BA);
    rect(371, 269, 114, 157, dark);
    rect(380, 277, 96, 140, fur);
    rect(389, 296, 56, 107, light);
    rect(358, 173, 113, 110, dark);
    rect(367, 181, 96, 95, fur);
    rect(372, 186, 43, 71, light);
    rect(332, 189, 37, 113, dark);
    rect(339, 197, 24, 96, fur);
    rect(459, 189, 36, 113, dark);
    rect(464, 197, 24, 96, fur);
    rect(370, 404, 42, 39, dark);
    rect(419, 404, 42, 39, dark);
    rect(377, 410, 28, 26, light);
    rect(426, 410, 28, 26, light);
    rect(377, 208, 14, 16, dark);
    rect(426, 208, 14, 16, dark);
    rect(399, 237, 20, 14, dark);
    rect(390, 255, 38, 6, dark);
    final tail = (math.sin(frame * math.pi * 8) * 9).roundToDouble();
    rect(477, 349 + tail, 54, 18, dark);
    rect(519, 319 + tail, 16, 42, dark);
    rect(481, 353 + tail, 45, 10, fur);
    c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(PixelRoomPainter old) =>
      style != old.style || frame != old.frame;
}

class FurniturePainter extends CustomPainter {
  final String id;
  FurniturePainter(this.id);
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 100, size.height / 100);
    void r(double x, double y, double w, double h, Color color) => c.drawRect(
      Rect.fromLTWH(x, y, w, h),
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
    const green = Color(0xFF527D51),
        brown = Color(0xFFB77F50),
        gold = Color(0xFFE8B85B);
    switch (id) {
      case 'plant':
        r(30, 55, 45, 40, brown);
        r(48, 15, 10, 45, green);
        r(20, 25, 35, 15, green);
        r(55, 10, 28, 20, green);
      case 'bed':
        r(5, 45, 90, 40, brown);
        r(15, 35, 70, 40, gold);
        r(25, 45, 50, 25, const Color(0xFFF5EBDD));
      case 'ball':
        r(25, 30, 50, 50, green);
        r(35, 20, 30, 70, green);
        r(20, 40, 60, 30, green);
        r(30, 35, 20, 15, gold);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(FurniturePainter old) => id != old.id;
}
