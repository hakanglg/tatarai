# Utils - Yardımcı Sınıflar

Bu klasör, uygulama genelinde kullanılan yardımcı sınıfları ve fonksiyonları içerir.

## PermissionManager

`PermissionManager`, uygulama genelinde izin yönetimini merkezi olarak yapan bir sınıftır. Kamera, galeri, mikrofon, konum vb. izinlerini yönetir ve kullanıcıya uygun bildirimler gösterir.

### Kullanım Örnekleri

#### Tek İzin İsteme

```dart
// Kamera izni isteme
bool hasPermission = await PermissionManager.requestPermission(
  AppPermissionType.camera,
  context: context, // İzin reddedilirse diyalog gösterilmesi için context
);

if (hasPermission) {
  // İzin verildi, kamerayı kullanabilirsiniz
  _openCamera();
} else {
  // İzin reddedildi, kullanıcı bilgilendirildi
  AppLogger.w('Kamera izni reddedildi');
}
```

#### Çoklu İzin İsteme

```dart
// Birden fazla izin isteme (kamera ve galeri)
final results = await PermissionManager.requestMultiplePermissions(
  [AppPermissionType.camera, AppPermissionType.photos],
  context: context,
);

// Tüm izinlerin verilip verilmediğini kontrol et
final allGranted = !results.values.contains(false);

if (allGranted) {
  // Tüm izinler verildi, işleme devam edebilirsiniz
} else {
  // En az bir izin reddedildi
  AppLogger.w('Bazı izinler reddedildi');
}
```

#### Sadece İzin Durumunu Kontrol Etme

```dart
// Bildirimlere izin verilip verilmediğini kontrol et
bool hasNotificationPermission = await PermissionManager.hasPermission(
  AppPermissionType.notification,
);
```

### Desteklenen İzin Türleri

`AppPermissionType` enum'ı içinde tanımlı izin türleri:

- `camera`: Kamera erişimi
- `photos`: Fotoğraf galerisi erişimi (iOS) / Medya erişimi (Android)
- `microphone`: Mikrofon erişimi
- `location`: Konum erişimi
- `storage`: Depolama erişimi (çoğunlukla Android için)
- `notification`: Bildirim izni

### Özellikler

- Otomatik olarak izin reddedildiğinde kullanıcıya diyalog gösterir
- Kalıcı olarak reddedilen izinlerde uygulama ayarlarına yönlendiren diyalog sunar
- Platform özelliklerine göre uygun izinleri ister (iOS vs Android)
- İzin durumlarını loglar

## Diğer Yardımcı Sınıflar

- `logger.dart`: Uygulama genelinde log yönetimi için kullanılır
- ... 