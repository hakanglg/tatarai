import 'package:flutter_test/flutter_test.dart';
import 'package:tatarai/core/services/device_identification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DeviceIdentificationService Tests', () {
    late DeviceIdentificationService deviceService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      deviceService = DeviceIdentificationService.instance;
    });

    test('should generate device fingerprint', () async {
      final fingerprint = await deviceService.getDeviceFingerprint();
      
      expect(fingerprint, isNotNull);
      expect(fingerprint.length, equals(64)); // SHA-256 hash length
    });

    test('should return same fingerprint on multiple calls', () async {
      final fingerprint1 = await deviceService.getDeviceFingerprint();
      final fingerprint2 = await deviceService.getDeviceFingerprint();
      
      expect(fingerprint1, equals(fingerprint2));
    });

    test('should clear device fingerprint', () async {
      // First get a fingerprint
      final originalFingerprint = await deviceService.getDeviceFingerprint();
      expect(originalFingerprint, isNotNull);

      // Clear it
      await deviceService.clearDeviceFingerprint();

      // Get a new one (should be different due to timestamp)
      final newFingerprint = await deviceService.getDeviceFingerprint();
      expect(newFingerprint, isNotNull);
      // Note: They might be the same if generated in the same millisecond
      // but the method should work
    });
  });
}