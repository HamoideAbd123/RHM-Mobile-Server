import 'package:flutter_test/flutter_test.dart';
import 'package:rhm_mobile/server_update_notifications.dart';

void main() {
  group('parseRhmClockMinutes', () {
    test('accepts valid zero-padded 24-hour times', () {
      expect(parseRhmClockMinutes('00:00'), 0);
      expect(parseRhmClockMinutes('09:05'), 545);
      expect(parseRhmClockMinutes('22:00'), 1320);
      expect(parseRhmClockMinutes('23:59'), 1439);
    });

    test('rejects malformed and out-of-range times', () {
      expect(parseRhmClockMinutes(null), isNull);
      expect(parseRhmClockMinutes('9:05'), isNull);
      expect(parseRhmClockMinutes('22:0'), isNull);
      expect(parseRhmClockMinutes(r'\d{2}:\d{2}'), isNull);
      expect(parseRhmClockMinutes('24:00'), isNull);
      expect(parseRhmClockMinutes('12:60'), isNull);
      expect(parseRhmClockMinutes('ab:cd'), isNull);
    });
  });

  group('isRhmQuietHoursActive', () {
    const overnight = {'enabled': true, 'start': '22:00', 'end': '07:00'};
    test('handles a quiet period that crosses midnight', () {
      expect(
        isRhmQuietHoursActive(overnight, now: DateTime(2026, 11, 10, 23, 0)),
        isTrue,
      );
      expect(
        isRhmQuietHoursActive(overnight, now: DateTime(2026, 11, 10, 6, 59)),
        isTrue,
      );
      expect(
        isRhmQuietHoursActive(overnight, now: DateTime(2026, 11, 10, 7, 0)),
        isFalse,
      );
    });

    test('handles a quiet period within the same day', () {
      const daytime = {'enabled': true, 'start': '09:00', 'end': '17:00'};
      expect(
        isRhmQuietHoursActive(daytime, now: DateTime(2026, 11, 10, 8, 59)),
        isFalse,
      );
      expect(
        isRhmQuietHoursActive(daytime, now: DateTime(2026, 11, 10, 9, 0)),
        isTrue,
      );
      expect(
        isRhmQuietHoursActive(daytime, now: DateTime(2026, 11, 10, 16, 59)),
        isTrue,
      );
      expect(
        isRhmQuietHoursActive(daytime, now: DateTime(2026, 11, 10, 17, 0)),
        isFalse,
      );
    });

    test('fails open when disabled or preferences are invalid', () {
      expect(
        isRhmQuietHoursActive(
          const {'enabled': false, 'start': '22:00', 'end': '07:00'},
          now: DateTime(2026, 11, 10, 23, 0),
        ),
        isFalse,
      );
      expect(
        isRhmQuietHoursActive(
          const {'enabled': true, 'start': 'invalid', 'end': '07:00'},
          now: DateTime(2026, 11, 10, 23, 0),
        ),
        isFalse,
      );
      expect(
        isRhmQuietHoursActive(
          const {'enabled': true, 'start': '08:00', 'end': '08:00'},
          now: DateTime(2026, 11, 10, 9, 0),
        ),
        isFalse,
      );
    });
  });
}
