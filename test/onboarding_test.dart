import 'package:chacha243/ui/onboarding_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sans « Continuer », l\'explication revient à chaque ouverture', () async {
    for (var i = 0; i < 5; i++) {
      await Onboarding.load();
      expect(Onboarding.pending, isTrue);
    }
  });

  test('après « Continuer », l\'explication ne revient plus', () async {
    await Onboarding.finish();
    await Onboarding.load();
    expect(Onboarding.pending, isFalse);
  });
}
