import 'dart:io';
import 'package:flutter/services.dart';

abstract interface class FileTransfer {
  Future<bool> share(File file);
  Future<Uint8List?> pickBackup();
}

class PlatformFileTransfer implements FileTransfer {
  static const channel = MethodChannel('mungcation/files');
  @override
  Future<bool> share(File file) async =>
      await channel.invokeMethod<bool>('share', {'path': file.path}) ?? false;
  @override
  Future<Uint8List?> pickBackup() =>
      channel.invokeMethod<Uint8List>('pickBackup');
}

// Both native platforms implement the same file-transfer contract.
typedef IosFileTransfer = PlatformFileTransfer;
