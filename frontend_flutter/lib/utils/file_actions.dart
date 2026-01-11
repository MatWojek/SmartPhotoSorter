import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openLocalFile(BuildContext ctx, String path) async {
  try {
    if (kIsWeb) throw UnsupportedError('web');
    if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [path.replaceAll('/', '\\')]);
    } else {
      throw UnsupportedError('platform');
    }
  } catch (_) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Cannot open locally.')));
  }
}

Future<void> downloadPhotoUrl(BuildContext ctx, Uri url) async {
  try {
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('launch failed');
  } catch (_) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Cannot open download link.')));
  }
}

Future<void> copyPath(BuildContext ctx, String path) async {
  await Clipboard.setData(ClipboardData(text: path));
  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Path copied')));
}

Future<void> revealInFolder(BuildContext ctx, String path) async {
  try {
    if (Platform.isLinux) {
      await Process.run('xdg-open', [Directory(path).path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [Directory(path).path]);
    } else if (Platform.isWindows) {
      final dir = Directory(path).path.replaceAll('/', '\\');
      await Process.run('explorer', [dir]);
    }
  } catch (_) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Cannot reveal folder.')));
  }
}