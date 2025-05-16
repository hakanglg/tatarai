# Firebase Remote Config ile Force Update Sistemi

Bu sistem, TatarAI uygulamasının kullanıcılarını en son sürüme yönlendirmek için Firebase Remote Config kullanır. Böylece uygulamanızın güncellenmesini zorunlu kılabilir veya isteğe bağlı güncellemeler sunabilirsiniz.

## Nasıl Çalışır?

1. Uygulama başlangıcında, `VersionUtil.initRemoteConfig()` çağrısı yapılarak Firebase Remote Config'ten ayarlar alınır.
2. Splash ekranında, `VersionUtil.checkAppVersion()` metodu çağrılarak kullanıcının uygulamasının güncel olup olmadığı kontrol edilir.
3. Eğer kullanıcının sürümü minimum gerekli sürümün altındaysa, `ForceUpdateScreen` gösterilir.
4. Eğer kullanıcının sürümü güncel değil ama zorunlu değilse, isteğe bağlı güncelleme önerilir.

## Remote Config Parametreleri

Aşağıdaki parametreler Firebase Remote Config konsolunda ayarlanmalıdır:

### iOS için:
- `ios_min_version`: Zorunlu güncelleme için minimum sürüm (örn. "1.0.0")
- `ios_latest_version`: En son mevcut sürüm (örn. "1.2.0")
- `ios_store_url`: App Store URL'si

### Android için:
- `android_min_version`: Zorunlu güncelleme için minimum sürüm (örn. "1.0.0")
- `android_latest_version`: En son mevcut sürüm (örn. "1.2.0")
- `android_store_url`: Google Play Store URL'si

### Mesajlar (her dil için):
- `force_update_message_tr`: Türkçe zorunlu güncelleme mesajı
- `force_update_message_en`: İngilizce zorunlu güncelleme mesajı
- `optional_update_message_tr`: Türkçe isteğe bağlı güncelleme mesajı
- `optional_update_message_en`: İngilizce isteğe bağlı güncelleme mesajı

## Örnek Değerler

```json
{
  "ios_min_version": "1.0.0",
  "ios_latest_version": "1.2.0",
  "ios_store_url": "https://apps.apple.com/app/id0000000000",
  "android_min_version": "1.0.0",
  "android_latest_version": "1.2.0",
  "android_store_url": "https://play.google.com/store/apps/details?id=com.tatarai.app",
  "force_update_message_tr": "Uygulamanızı güncelleştirmeniz gerekiyor. Yeni özellikleri kullanabilmek ve güvenlik güncellemelerinden yararlanabilmek için lütfen şimdi güncelleyin.",
  "force_update_message_en": "You need to update your application. Please update now to use the latest features and security updates.",
  "optional_update_message_tr": "Yeni bir güncelleme mevcut! Daha iyi bir deneyim için güncellemeyi öneririz.",
  "optional_update_message_en": "A new update is available! We recommend updating for the best experience."
}
```

## Firebase Remote Config Konsolu

Remote Config değerlerini Firebase konsolunda ayarlamak için:

1. Firebase konsolunda projenize gidin
2. Soldaki menüden "Remote Config"i seçin
3. "Parametre ekle" butonuna tıklayın
4. Her parametre için yukarıdaki anahtarları kullanın
5. Değerler için uygun versiyonları ve mesajları girin
6. "Değişiklikleri yayınla" butonuna tıklayın

## Önemli Notlar

- Sürüm karşılaştırması için `SemanticVersion` sınıfı kullanılır (örn. "1.2.0" > "1.1.9")
- Remote Config varsayılan olarak önbelleğe alınır, bu nedenle değişikliklerinizin etkili olması için bir süre geçmesi gerekebilir
- Test sırasında `minimumFetchInterval` değeri düşürülebilir 