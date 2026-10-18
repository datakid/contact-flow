import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import '../models/person.dart';

enum DeviceAccess { granted, denied, blocked, unsupported }

class DeviceContacts {
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<DeviceAccess> request({bool write = false}) async {
    if (!supported) return DeviceAccess.unsupported;
    final s = await fc.FlutterContacts.permissions.request(
      write ? fc.PermissionType.readWrite : fc.PermissionType.read,
    );
    return switch (s) {
      fc.PermissionStatus.granted ||
      fc.PermissionStatus.limited => DeviceAccess.granted,
      fc.PermissionStatus.permanentlyDenied ||
      fc.PermissionStatus.restricted => DeviceAccess.blocked,
      _ => DeviceAccess.denied,
    };
  }

  static Future<void> openSettings() =>
      fc.FlutterContacts.permissions.openSettings();

  static String _label(fc.PhoneLabel l) => switch (l) {
    fc.PhoneLabel.home => 'home',
    fc.PhoneLabel.work || fc.PhoneLabel.workMobile => 'work',
    fc.PhoneLabel.homeFax ||
    fc.PhoneLabel.workFax ||
    fc.PhoneLabel.otherFax => 'fax',
    fc.PhoneLabel.main || fc.PhoneLabel.companyMain => 'main',
    fc.PhoneLabel.pager || fc.PhoneLabel.workPager => 'pager',
    fc.PhoneLabel.other => 'other',
    _ => 'mobile',
  };

  static fc.PhoneLabel _toLabel(String l) => switch (l) {
    'home' => fc.PhoneLabel.home,
    'work' => fc.PhoneLabel.work,
    'fax' => fc.PhoneLabel.workFax,
    'main' => fc.PhoneLabel.main,
    'pager' => fc.PhoneLabel.pager,
    'other' => fc.PhoneLabel.other,
    _ => fc.PhoneLabel.mobile,
  };

  static Future<List<Person>> readAll() async {
    final list = await fc.FlutterContacts.getAll(
      properties: {
        fc.ContactProperty.name,
        fc.ContactProperty.phone,
        fc.ContactProperty.email,
        fc.ContactProperty.organization,
      },
    );
    final out = <Person>[];
    for (final c in list) {
      final phones = c.phones
          .map((p) => PhoneEntry(p.number, _label(p.label.label)))
          .toList();
      final emails = c.emails.map((e) => e.address).toList();
      if (phones.isEmpty && emails.isEmpty) continue;
      out.add(
        Person(
          name: c.displayName ?? '',
          phones: phones,
          emails: emails,
          org: c.organizations.isEmpty
              ? ''
              : (c.organizations.first.name ?? ''),
          source: 'device',
        ),
      );
    }
    return out;
  }
}
