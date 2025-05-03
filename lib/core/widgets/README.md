# Merkezi Diyalog Yönetimi

Uygulama genelinde tutarlı görünüm ve davranış için diyalog gösterimlerini merkezileştiren bileşenler.

## AppDialogManager

AppDialogManager, uygulama içindeki tüm diyalog gösterimlerini merkezi ve tutarlı bir şekilde yönetmek için tasarlanmıştır. Bu sınıf sayesinde uygulamanın farklı bölümlerinde aynı tarzda ve tutarlı diyaloglar gösterebilirsiniz.

### Kullanım Örnekleri

#### Bilgi Diyaloğu
```dart
AppDialogManager.showInfoDialog(
  context: context,
  title: 'Bilgi',
  message: 'İşlem başarıyla tamamlandı.',
);
```

#### Hata Diyaloğu
```dart
AppDialogManager.showErrorDialog(
  context: context,
  title: 'Hata',
  message: 'Bağlantı hatası oluştu. Lütfen internet bağlantınızı kontrol ediniz.',
);
```

#### Onay Diyaloğu
```dart
final result = await AppDialogManager.showConfirmDialog(
  context: context,
  title: 'Onay',
  message: 'Bu öğeyi silmek istediğinizden emin misiniz?',
  confirmText: 'Evet, Sil',
  cancelText: 'İptal',
);

if (result) {
  // Kullanıcı onayladı, silme işlemini gerçekleştir
  deleteItem();
}
```

#### Premium Diyaloğu
```dart
final result = await AppDialogManager.showPremiumRequiredDialog(
  context: context,
  message: 'Günlük analiz hakkınız doldu.',
  onPremiumButtonPressed: () {
    // Premium satın alma sayfasına yönlendir
    navigateToPremiumScreen();
  },
);
```

#### Ayarlar Diyaloğu
```dart
final openSettings = await AppDialogManager.showSettingsDialog(
  context: context,
  title: 'İzin Gerekli',
  message: 'Bu özelliği kullanabilmek için kamera izni vermeniz gerekmektedir.',
  onSettingsPressed: () {
    Navigator.pop(context, true);
    openAppSettings();
  },
);
```

#### Yükleniyor Diyaloğu
```dart
// Yükleniyor diyaloğunu göster
AppDialogManager.showLoadingDialog(
  context: context,
  message: 'Fotoğraf yükleniyor...',
);

// İşlem tamamlandıktan sonra diyaloğu kapat
try {
  await uploadPhoto();
  AppDialogManager.dismissDialog(context);
  
  // İşlem başarılı mesajı
  AppDialogManager.showInfoDialog(
    context: context,
    title: 'Başarılı',
    message: 'Fotoğraf başarıyla yüklendi.',
  );
} catch (e) {
  AppDialogManager.dismissDialog(context);
  
  // Hata mesajı
  AppDialogManager.showErrorDialog(
    context: context,
    title: 'Hata',
    message: 'Fotoğraf yüklenirken bir hata oluştu.',
  );
}
```

#### Özel İkonlu Diyalog
```dart
AppDialogManager.showIconDialog(
  context: context,
  icon: CupertinoIcons.lightbulb_fill,
  iconColor: AppColors.warning,
  title: 'İpucu',
  message: 'Daha iyi sonuçlar için fotoğrafı doğal ışıkta çekin.',
);
```

### Avantajları

1. **Tutarlılık**: Tüm uygulama genelinde aynı görünüm ve davranışa sahip diyaloglar
2. **Bakım Kolaylığı**: Diyalog tasarımını tek bir yerden güncelleme imkanı
3. **Kod Tekrarını Önleme**: Aynı diyalog kodunu tekrar tekrar yazmak yerine merkezi fonksiyonlardan faydalanma
4. **Tema Uyumluluğu**: Tüm diyaloglar uygulama temasıyla uyumlu şekilde çalışır
5. **Genişletilebilirlik**: Yeni diyalog türlerini kolayca ekleyebilme imkanı 