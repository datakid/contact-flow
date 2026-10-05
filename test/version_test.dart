import 'dart:io';

import 'package:contact_flow/ui/settings_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in-app version matches pubspec', () {
    final v = RegExp(
      r'^version:\s*([0-9.]+)',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(appVersion, v);
  });
}
