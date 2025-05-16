# Force Update Özelliği Uygulama Dökümanı

Bu döküman, TatarAI uygulaması için eklenen Force Update (Zorunlu Güncelleme) özelliğinin teknik detaylarını içerir.

## Genel Bakış

Force Update özelliği, kullanıcıların uygulamanın güncel sürümünü kullanmalarını sağlamak için tasarlanmıştır. İki tür güncelleme mekanizması içerir:

1. **Zorunlu Güncelleme (Force Update)**: Kullanıcı, belirli bir minimum sürümün altındaysa uygulamayı kullanmaya devam edemez ve güncelleme yapmak zorundadır.
2. **İsteğe Bağlı Güncelleme (Optional Update)**: Kullanıcı, güncel sürümü kullanmıyorsa ancak minimum sürümün üzerindeyse, güncelleme yapması önerilir ama zorunlu değildir.

## Mimari

Sistem aşağıdaki bileşenlerden oluşur:

1. **Firestore Veritabanı**: Sürüm bilgilerini ve güncelleme ayarlarını saklar.
2. **VersionUtil**: Sürüm kontrolü yapan yardımcı sınıf.
3. **SemanticVersion**: Sürüm numaralarını karşılaştırmak için kullanılan sınıf.
4. **ForceUpdateScreen**: Zorunlu güncelleme ekranı.
5. **UpdateDialog**: İsteğe bağlı güncelleme dialogu.

## Veri Modeli

Firestore'da `settings` koleksiyonunda `app_versions` dökümanı aşağıdaki yapıdadır:

```json
{
  "ios": {
    "min_version": "1.0.0",
    "latest_version": "1.2.0",
    "force_message": "Uygulamayı kullanmaya devam etmek için güncelleme yapmanız gerekmektedir.",
    "update_message": "Yeni bir güncelleme mevcut. Lütfen güncelleme yapın.",
    "store_url": "https://apps.apple.com/app/idXXXXXXXXXX"
  },
  "android": {
    "min_version": "1.0.0",
    "latest_version": "1.2.0",
    "force_message": "Uygulamayı kullanmaya devam etmek için güncelleme yapmanız gerekmektedir.",
    "update_message": "Yeni bir güncelleme mevcut. Lütfen güncelleme yapın.",
    "store_url": "https://play.google.com/store/apps/details?id=com.tatarai.app"
  },
  "last_update": "2024-06-15T12:00:00Z"
}
```

## Akış

1. **Uygulama Başlangıcı**:
   - Uygulama SplashScreen'de başlar.
   - Animasyon gösterilirken, VersionUtil kullanılarak sürüm kontrolü yapılır.
   - Eğer zorunlu güncelleme gerekiyorsa, ForceUpdateScreen gösterilir.
   - Değilse, normal uygulama akışına devam edilir.

2. **Ana Ekran**:
   - Kullanıcı ana ekrana geldiğinde, isteğe bağlı güncelleme kontrolü yapılır.
   - Eğer isteğe bağlı güncelleme varsa, UpdateDialog gösterilir.
   - Kullanıcı güncellemeyi kabul ederse, uygulama mağazasına yönlendirilir.
   - Kullanıcı "Daha Sonra" seçeneğini seçerse, dialog kapatılır ve normal kullanıma devam edilir.

## Dosyalar ve Sorumlulukları

1. **lib/core/utils/semantic_version.dart**:
   - Sürüm numaralarını karşılaştırmak için kullanılan sınıf.
   - Semver standardına uygun olarak major.minor.patch formatını destekler.

2. **lib/core/utils/version_util.dart**:
   - Firestore'dan sürüm bilgilerini alır.
   - Mevcut uygulama sürümü ile karşılaştırma yapar.
   - Güncelleme durumunu döndürür (upToDate, updateAvailable, forceUpdateRequired).

3. **lib/features/update/views/force_update_screen.dart**:
   - Zorunlu güncelleme gerektiğinde gösterilen ekran.
   - Kullanıcıya güncelleme yapması gerektiğini bildirir.
   - Mağazaya yönlendiren buton içerir.

4. **lib/features/update/views/update_dialog.dart**:
   - İsteğe bağlı güncellemeler için gösterilen dialog.
   - Kullanıcıya güncelleme yapmasını önerir.
   - "Güncelle" ve "Daha Sonra" seçenekleri sunar.

5. **lib/features/splash/views/splash_screen.dart**:
   - Uygulama başlangıcında sürüm kontrolü yapar.
   - Gerekirse ForceUpdateScreen'e yönlendirir.

6. **lib/features/home/views/home_screen.dart**:
   - Ana ekranda isteğe bağlı güncelleme kontrolü yapar.
   - Gerekirse UpdateDialog gösterir.

## Kullanım

Zorunlu güncelleme gerektiğinde, kullanıcı uygulamayı kullanmaya devam edemez ve mağazaya yönlendirilir. İsteğe bağlı güncelleme durumunda, kullanıcıya güncelleme önerilir ancak zorunlu değildir.

## Firestore Yapılandırması

1. Firebase Console'a giriş yapın.
2. Firestore Database'i açın.
3. `settings` koleksiyonunu oluşturun (yoksa).
4. `app_versions` ID'li bir döküman oluşturun.
5. Yukarıdaki veri modelindeki yapıyı ekleyin.

## Güncelleme Senaryoları

### Zorunlu Güncelleme

Firestore'da `min_version` değerini artırarak zorunlu güncelleme yapılabilir. Örneğin, mevcut sürüm 1.0.0 ise ve `min_version` 1.1.0 olarak ayarlanırsa, 1.0.0 sürümünü kullanan tüm kullanıcılar güncelleme yapmak zorunda kalır.

### İsteğe Bağlı Güncelleme

`latest_version` değerini artırarak isteğe bağlı güncelleme yapılabilir. Örneğin, mevcut sürüm 1.1.0 ise ve `latest_version` 1.2.0 olarak ayarlanırsa, kullanıcılara güncelleme önerilir ancak zorunlu değildir.

## Notlar

- Uygulama sürümü, pubspec.yaml dosyasındaki `version` alanından alınır.
- Firestore'da platform spesifik ayarlar (iOS/Android) yapılabilir.
- Güncelleme mesajları özelleştirilebilir.
- Mağaza URL'leri platform bazında ayarlanabilir. 