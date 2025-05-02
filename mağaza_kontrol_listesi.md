# TatarAI Mağaza Yükleme Kontrol Listesi

## Android (Google Play Store) Hazırlığı

- [ ] pubspec.yaml'da versiyon numarası güncel (1.0.0+1)
- [ ] Android app/build.gradle dosyasında imzalama ayarları doğru yapılandırıldı
- [ ] key.properties dosyası oluşturuldu ve doğru şekilde yapılandırıldı
- [ ] AndroidManifest.xml'de gerekli tüm izinler doğru tanımlandı
- [ ] Google Play hesabı oluşturuldu ve geliştirici ücreti ödendi
- [ ] Uygulama simgesi gereksinimlere uygun (512x512 PNG)
- [ ] Öne çıkan görsel hazırlandı (1024x500 PNG veya JPG)
- [ ] Farklı cihazlar için ekran görüntüleri hazırlandı (en az 2 adet)
- [ ] Uygulama APK/AAB test edildi ve çalışıyor
- [ ] Mağaza açıklaması hazırlandı
- [ ] Gizlilik politikası URL'si hazırlandı
- [ ] İletişim bilgileri güncel
- [ ] Play Console'da içerik derecelendirme anketi tamamlandı
- [ ] Hedef kitle ve içerik derecelendirmesi belirtildi
- [ ] Fiyat ve Dağıtım ayarları yapılandırıldı
- [ ] In-app satın almalar tanımlandı (varsa)
- [ ] App Signing sertifikaları hazırlandı

## iOS (App Store) Hazırlığı

- [ ] pubspec.yaml'da versiyon numarası güncel (1.0.0+1)
- [ ] Apple Developer hesabı aktif ve ücretleri ödendi 
- [ ] App Store Connect'te uygulama kaydı oluşturuldu
- [ ] Bundle Identifier ayarlandı ve doğru
- [ ] Xcode'da uygulama imzalama için sertifikalar ve profiller oluşturuldu
- [ ] App Store Connect'te uygulama meta verileri (açıklama, anahtar kelimeler vs.) girildi
- [ ] iPhone ekran görüntüleri (6.5", 5.5" ekranlar için)
- [ ] iPad ekran görüntüleri (varsa)
- [ ] App Store simgesi yüklendi (1024x1024 PNG)
- [ ] Gizlilik politikası URL'si eklendi
- [ ] Destek URL'si eklendi
- [ ] Pazarlama URL'si eklendi (opsiyonel)
- [ ] Telif hakkı bilgisi eklendi
- [ ] Apple Gizlilik bildirimleri dolduruldu (veri toplama, kullanım, paylaşım)
- [ ] Uygulama içi satın alma öğeleri yapılandırıldı (varsa)
- [ ] TestFlight beta testi yapıldı
- [ ] App Store ön inceleme ekran görüntüleri/videoları hazırlandı
- [ ] İçerik hakları beyanı tamamlandı
- [ ] IDFA kullanımı açıklandı (varsa)
- [ ] Export Compliance bilgileri dolduruldu

## Firebase Ayarları

- [ ] Firebase projesi ve yapılandırması doğru
- [ ] Authentication servisi düzgün çalışıyor
- [ ] Firestore kuralları güvenli ve test edildi
- [ ] Storage kuralları güvenli ve test edildi
- [ ] Analytics etkinleştirildi ve olaylar yapılandırıldı
- [ ] Crashlytics etkinleştirildi ve doğru çalışıyor

## Son Testler

- [ ] Uygulama farklı cihazlarda test edildi
- [ ] Tüm ekran boyutları test edildi
- [ ] Tüm özellikler test edildi
- [ ] Çevrimdışı davranış test edildi
- [ ] Çökme testleri yapıldı
- [ ] In-app satın almalar test edildi (varsa)
- [ ] Performans testleri yapıldı
- [ ] Kullanılabilirlik testleri yapıldı

## Canlıya Alma

- [ ] Android: `flutter build appbundle --release` komutu çalıştırıldı
- [ ] iOS: Xcode ile Archive oluşturuldu
- [ ] Android: Google Play Console'da yeni sürüm oluşturuldu ve paket yüklendi
- [ ] iOS: App Store Connect'e paket yüklendi
- [ ] Her iki platformda da inceleme notları eklendi
- [ ] İnceleme için gönderim yapıldı 