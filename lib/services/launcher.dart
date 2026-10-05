import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class Launcher {
  Future<bool> open(Uri uri);
  Future<bool> canOpen(Uri uri);
}

class SystemLauncher implements Launcher {
  const SystemLauncher();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canOpen(Uri uri) async {
    if (kIsWeb) return true;
    try {
      return await canLaunchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}

class RecordingLauncher implements Launcher {
  final List<Uri> opened = [];
  bool available;
  RecordingLauncher({this.available = true});

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return available;
  }

  @override
  Future<bool> canOpen(Uri uri) async => available;
}
