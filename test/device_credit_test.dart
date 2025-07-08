import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatarai/core/models/device_credit_model.dart';

void main() {
  group('DeviceCreditModel Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should create first time device credit model', () {
      final model = DeviceCreditModel.firstTime(
        deviceId: 'test_device_123',
        userId: 'user_456',
      );

      expect(model.deviceId, equals('test_device_123'));
      expect(model.hasCreditBeenGranted, isTrue);
      expect(model.lastUserId, equals('user_456'));
      expect(model.attemptCount, equals(1));
      expect(model.shouldGrantCredit, isFalse);
      expect(model.hasHistory, isTrue);
    });

    test('should create subsequent device credit model', () {
      final existing = DeviceCreditModel.firstTime(
        deviceId: 'test_device_123',
        userId: 'user_456',
      );

      final subsequent = DeviceCreditModel.subsequent(
        deviceId: 'test_device_123',
        userId: 'user_789',
        existing: existing,
      );

      expect(subsequent.deviceId, equals('test_device_123'));
      expect(subsequent.hasCreditBeenGranted, isTrue);
      expect(subsequent.lastUserId, equals('user_789'));
      expect(subsequent.attemptCount, equals(2));
      expect(subsequent.shouldGrantCredit, isFalse);
    });

    test('should serialize to and from JSON correctly', () {
      final original = DeviceCreditModel.firstTime(
        deviceId: 'test_device_123',
        userId: 'user_456',
      );

      final json = original.toJson();
      final restored = DeviceCreditModel.fromJson(json);

      expect(restored.deviceId, equals(original.deviceId));
      expect(restored.hasCreditBeenGranted, equals(original.hasCreditBeenGranted));
      expect(restored.lastUserId, equals(original.lastUserId));
      expect(restored.attemptCount, equals(original.attemptCount));
    });

    test('should indicate when credit should be granted', () {
      // New device - should grant credit
      final newDevice = DeviceCreditModel(
        deviceId: 'new_device',
        hasCreditBeenGranted: false,
        updatedAt: DateTime.now(),
      );
      expect(newDevice.shouldGrantCredit, isTrue);

      // Used device - should not grant credit
      final usedDevice = DeviceCreditModel.firstTime(
        deviceId: 'used_device',
        userId: 'user_123',
      );
      expect(usedDevice.shouldGrantCredit, isFalse);
    });
  });
}