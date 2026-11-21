import 'package:flutter_test/flutter_test.dart';
import 'package:rhm_mobile/more_tab_availability.dart';

void main() {
  group('shouldShowMoreServerModules', () {
    test('hides server modules when a saved client is not connected', () {
      expect(
        shouldShowMoreServerModules(
          hasApiClient: true,
          connectionReady: false,
        ),
        isFalse,
      );
    });

    test('hides server modules when no client exists', () {
      expect(
        shouldShowMoreServerModules(
          hasApiClient: false,
          connectionReady: true,
        ),
        isFalse,
      );
    });

    test('shows server modules only after a confirmed connection', () {
      expect(
        shouldShowMoreServerModules(
          hasApiClient: true,
          connectionReady: true,
        ),
        isTrue,
      );
    });
  });
}
