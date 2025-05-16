# Force Update için Firestore Şeması

Firebase Console'dan aşağıdaki şekilde veri yapısı oluşturulmalıdır.

## Koleksiyon ve Döküman Yapısı

**Koleksiyon**: `settings`
**Döküman ID**: `app_versions`

## Veri Yapısı

```json
{
  "ios": {
    "min_version": "1.0.0", // Zorunlu güncelleme için minimum sürüm
    "latest_version": "1.2.0", // En son sürüm
    "force_message": "Uygulamayı kullanmaya devam etmek için güncelleme yapmanız gerekmektedir.", // Zorunlu güncelleme mesajı
    "update_message": "Yeni bir güncelleme mevcut. Lütfen güncelleme yapın.", // İsteğe bağlı güncelleme mesajı
    "store_url": "https://apps.apple.com/app/idXXXXXXXXXX" // App Store URL'si
  },
  "android": {
    "min_version": "1.0.0", // Zorunlu güncelleme için minimum sürüm
    "latest_version": "1.2.0", // En son sürüm
    "force_message": "Uygulamayı kullanmaya devam etmek için güncelleme yapmanız gerekmektedir.", // Zorunlu güncelleme mesajı
    "update_message": "Yeni bir güncelleme mevcut. Lütfen güncelleme yapın.", // İsteğe bağlı güncelleme mesajı
    "store_url": "https://play.google.com/store/apps/details?id=com.tatarai.app" // Play Store URL'si
  },
  "last_update": "2024-06-15T12:00:00Z" // Son güncelleme tarihi
}
```

## Kullanım

1. Firebase Console'a giriş yapın
2. Firestore Database'i açın
3. `settings` koleksiyonunu oluşturun (yoksa)
4. `app_versions` ID'li bir döküman oluşturun
5. Yukarıdaki veri yapısını ekleyin

## Sürüm Güncelleme Örneği

### Örnek 1: Normal Güncelleme (Zorunlu Değil)

```json
{
  "ios": {
    "min_version": "1.0.0", // Değişmedi
    "latest_version": "1.3.0", // Yeni sürüm
    "update_message": "Performans iyileştirmeleri ve yeni özellikler eklendi!" // Güncellenmiş mesaj
  }
}
```

### Örnek 2: Zorunlu Güncelleme

```json
{
  "ios": {
    "min_version": "1.2.0", // Min sürümü artırarak zorunlu güncelleme yaratıldı
    "latest_version": "1.3.0", 
    "force_message": "Kritik güvenlik güncellemesi yapmanız gerekmektedir." // Zorunlu güncelleme mesajı değiştirildi
  }
}
```

## Notlar

- `min_version` değerini artırmak, bu sürümün altındaki tüm kullanıcılar için zorunlu güncelleme yaratır
- Semantik sürümlendirme kullanılmalıdır (örn. 1.0.0, 1.2.3, vb.)
- Store URL'leri ile ilgili App Store ve Google Play Store'daki doğru uygulama URL'lerini kullanın 