# TatarAI Uygulaması Mağaza Yükleme Kılavuzu

Bu belge, TatarAI uygulamasını App Store ve Google Play Store'a yükleme sürecini açıklar.

## 1. Hazırlık Adımları

### Versiyon Numarası Kontrolü
Uygulama versiyon numarasını pubspec.yaml dosyasında kontrol edin ve gerekirse güncelleyin:
```yaml
version: 1.0.0+1
```
- İlk kısım (1.0.0) semantik versiyon numarasıdır.
- İkinci kısım (+1) derleme numarasıdır.

Her yeni sürüm için versiyon numarasını artırın. Örneğin, önemli bir güncelleme için 1.1.0+2.

## 2. Android için Hazırlık

### 1. `key.properties` Dosyası
Android imzalama için `android/key.properties` dosyasının mevcut olduğundan emin olun:

```
storePassword=<şifre>
keyPassword=<şifre>
keyAlias=upload
storeFile=<anahtar dosyası konumu>
```

### 2. `build.gradle` İmzalama Konfigürasyonu
Android/app/build.gradle dosyasında imzalama yapılandırmasının doğru olduğundan emin olun.

### 3. İzinlerin Doğruluğu
AndroidManifest.xml'de gerekli tüm izinler eklendi. Şu anda:
- Kamera
- Depolama

### 4. Yazı Tiplerini Kontrol Edin
`sfpro` yazı tipi varlıkları eklenmiş durumda.

### 5. Release Build Oluşturma
```bash
flutter build appbundle
```

## 3. iOS için Hazırlık

### 1. Bundle ID ve Sertifika
Apple Developer hesabında:
- Doğru Bundle ID'yi yapılandırın
- Sertifikaları ve profilleri oluşturun

### 2. Xcode'da Ayarlar
Xcode ile Runner.xcworkspace'i açın ve:
- Bundle ID'nin doğru olduğunu kontrol edin
- Takım bilgisini seçin
- Sertifikaları kontrol edin
- Deployment Target'ı ayarlayın (en az iOS 12.0 önerilen)

### 3. App Store Metadata
App Store Connect'te:
- Uygulama ekran görüntülerini (tüm cihaz boyutları için)
- Uygulama açıklamasını
- Anahtar kelimeleri
- Gizlilik politikasını
- Uygulama simgesini ekleyin

### 4. İzinler
Info.plist'teki tüm kullanıcı izinleri ve açıklamaları:
- Kamera erişimi: "Bu uygulama, bitki analizi için fotoğraf çekmek üzere kameranıza erişim gerektirir"
- Fotoğraf kitaplığı erişimi: "Bu uygulama, bitki analizi için galeriden fotoğraf seçmenize olanak tanımak için fotoğraf kitaplığınıza erişim gerektirir"

### 5. App Privacy (Apple Gizlilik)
Apple Gizlilik Bilgileri:
- Toplanan veri türlerini belirtin
- Verilerin nasıl kullanıldığını açıklayın
- Üçüncü taraf paylaşımını belirtin

### 6. Release Build Oluşturma
```bash
flutter build ios --release
```
Ardından Xcode üzerinden Archive kullanarak App Store Connect'e yükleyin.

## 4. Firebase Konfigürasyonu

Firebase projesinde:
1. Analytics ayarlarının etkin olduğundan emin olun
2. Crashlytics yapılandırmasını kontrol edin
3. Authentication ayarlarının doğru olduğunu kontrol edin

## 5. Son Kontroller

### 1. Ödeme sistemleri
In-app purchase'ların test edildiğinden emin olun.

### 2. Deep link kontrolü
Varsa deep link yapılandırmasını test edin.

### 3. Uygulamayı test edin
Son sürümü hem Android hem de iOS cihazlarda test edin.

## 6. Uygulama Gönderimi

### Android Gönderimi
1. Google Play Console'a giriş yapın
2. Uygulama oluşturun/seçin
3. App bundle (.aab) yükleyin
4. Tüm uygulama bilgilerini doldurun
5. Sürümü gözden geçirme için gönderin

### iOS Gönderimi
1. App Store Connect'e giriş yapın
2. Yeni sürümü oluşturun
3. Xcode üzerinden Archive ile oluşturduğunuz paketi yükleyin
4. Tüm uygulama bilgilerini doldurun
5. İnceleme için gönderin

## Notlar
- Sürüm testleri ve beta sürümleri için TestFlight ve Google Play Internal Test kanallarını kullanabilirsiniz
- Her mağaza gönderiminde gizlilik politikası URL'si gereklidir
- Ekran görüntülerinin güncel olduğundan emin olun 