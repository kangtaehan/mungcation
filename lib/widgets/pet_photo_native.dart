import 'dart:io';
import 'package:flutter/material.dart';
import '../services/media_store.dart';

class PetPhoto extends StatelessWidget {
  final String name;
  final bool pixel;
  const PetPhoto(this.name, {super.key, this.pixel = false});
  @override
  Widget build(BuildContext context) => FutureBuilder<File>(
    future: MediaStore.instance.resolve(name),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Icon(Icons.pets);
      return Image.file(
        snapshot.data!,
        fit: BoxFit.cover,
        filterQuality: pixel ? FilterQuality.none : FilterQuality.medium,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    },
  );
}
