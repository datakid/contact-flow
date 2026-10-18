import 'package:contact_flow/phone/phone_key.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> started(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final s = AppState();
  await s.init(openStore: false);
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => PhoneKey.useRegion(''));

  test('a saved +966 becomes the SA region', () async {
    final s = await started({'country': '+966'});
    expect(s.region, 'SA');
    expect(s.needsRegionPick, isFalse);
    expect(PhoneKey.regionCode, 'SA');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('region'), 'SA');
  });

  test('a saved +1 cannot be migrated and asks for a pick', () async {
    final s = await started({'country': '+1'});
    expect(s.region, '');
    expect(s.needsRegionPick, isTrue);
    expect(PhoneKey.region, isNull);
  });

  test('choosing a region fixes the pending pick', () async {
    final s = await started({'country': '+44'});
    await s.setRegion('GB');
    expect(s.region, 'GB');
    expect(s.country, '44');
    expect(s.needsRegionPick, isFalse);
    expect(PhoneKey.regionCode, 'GB');
  });

  test('typing a unique calling code sets the region', () async {
    final s = await started({});
    await s.setCountry('+971');
    expect(s.region, 'AE');
    expect(PhoneKey.regionCode, 'AE');
  });

  test('typing a shared calling code leaves the region to be picked', () async {
    final s = await started({});
    await s.setCountry('+1');
    expect(s.region, '');
    expect(s.needsRegionPick, isTrue);
  });

  test('with nothing saved and no detection there is no region', () async {
    final s = await started({});
    expect(s.region, '');
    expect(s.country, '');
    expect(s.needsRegionPick, isFalse);
  });

  test('a local number gets its international form from the region', () async {
    await started({'country': '+966'});
    expect(PhoneKey.e164('0501234567'), '+966501234567');
  });
}
