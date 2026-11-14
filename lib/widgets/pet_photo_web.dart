import 'package:flutter/material.dart';

class PetPhoto extends StatelessWidget {
  final String name;
  final bool pixel;
  const PetPhoto(this.name, {super.key, this.pixel = false});
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFFFE8C7),
    child: Center(child: Icon(Icons.pets, color: Color(0xFF205C40))),
  );
}
