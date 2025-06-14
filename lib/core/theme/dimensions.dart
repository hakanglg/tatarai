import 'package:flutter/cupertino.dart';

/// Responsive tasarım değerlerini tutan sınıf
/// Tüm projede sabit değerler yerine bu sınıf kullanılmalıdır
class AppDimensions {
  /// BuildContext üzerinden MediaQuery ile ekran boyutlarına erişebilmek için
  final BuildContext context;

  /// Constructor
  const AppDimensions(this.context);

  /// Ekran genişliği
  double get screenWidth => MediaQuery.of(context).size.width;

  /// Ekran yüksekliği
  double get screenHeight => MediaQuery.of(context).size.height;

  /// Ekran boyutuna göre ölçeklendirilmiş temel birim
  /// Responsive tasarım için kullanılacak temel değeri üretir
  double get unit => screenWidth / 100;

  /// Ekranın küçük olup olmadığını belirtir (< 360dp)
  bool get isSmallScreen => screenWidth < 360;

  /// Ekranın orta boyutta olup olmadığını belirtir (360dp - 720dp)
  bool get isMediumScreen => screenWidth >= 360 && screenWidth < 720;

  /// Ekranın büyük olup olmadığını belirtir (>= 720dp)
  bool get isLargeScreen => screenWidth >= 720;

  // Padding değerleri
  /// Küçük padding: 8dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get paddingXS => isSmallScreen ? unit * 1.6 : 8;

  /// Normal padding: 16dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get paddingS => isSmallScreen ? unit * 2.4 : 12;

  /// Orta padding: 16dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get paddingM => isSmallScreen ? unit * 3.2 : 16;

  /// Büyük padding: 24dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get paddingL => isSmallScreen ? unit * 4.8 : 24;

  /// Çok büyük padding: 32dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get paddingXL => isSmallScreen ? unit * 6.4 : 32;

  /// Aşırı büyük padding: 48dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get paddingXXL => isSmallScreen ? unit * 9.6 : 48;

  // Widget boyutları
  /// Buton yüksekliği: 48dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get buttonHeight => isSmallScreen ? unit * 10 : 48;

  /// Çok büyük icon boyutu: 48dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get iconSizeXL => isSmallScreen ? unit * 9 : 48;

  /// Büyük icon boyutu: 32dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get iconSizeL => isSmallScreen ? unit * 7 : 32;

  /// Normal icon boyutu: 24dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get iconSizeM => isSmallScreen ? unit * 5 : 24;

  /// Küçük icon boyutu: 20dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get iconSizeS => isSmallScreen ? unit * 4 : 20;

  /// Çok küçük icon boyutu: 16dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get iconSizeXS => isSmallScreen ? unit * 3 : 16;

  // Font boyutları
  /// Aşırı büyük font boyutu: 35dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get fontSizeXXL => isSmallScreen ? unit * 7 : 35;

  /// Alt başlık font boyutu: 27dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get fontSizeXL => isSmallScreen ? unit * 5.4 : 27;

  /// Büyük font boyutu: 23dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get fontSizeL => isSmallScreen ? unit * 4.6 : 23;

  /// Normal font boyutu: 19dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get fontSizeM => isSmallScreen ? unit * 3.8 : 19;

  /// Küçük font boyutu: 17dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get fontSizeS => isSmallScreen ? unit * 3.4 : 17;

  /// Çok küçük font boyutu: 15dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get fontSizeXS => isSmallScreen ? unit * 3 : 15;

  // Radius değerleri
  /// Küçük border radius: 4dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get radiusXS => isSmallScreen ? unit * 0.8 : 4;

  /// Normal border radius: 8dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get radiusS => isSmallScreen ? unit * 1.6 : 8;

  /// Orta border radius: 12dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get radiusM => isSmallScreen ? unit * 2.4 : 12;

  /// Büyük border radius: 16dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get radiusL => isSmallScreen ? unit * 3.2 : 16;

  // Boşluk değerleri
  /// Çok küçük boşluk: 4dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get spaceXXS => isSmallScreen ? unit * 0.8 : 4;

  /// Küçük boşluk: 8dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get spaceXS => isSmallScreen ? unit * 1.6 : 8;

  /// Normal boşluk: 12dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get spaceS => isSmallScreen ? unit * 2.4 : 12;

  /// Orta boşluk: 16dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get spaceM => isSmallScreen ? unit * 3.2 : 16;

  /// Büyük boşluk: 24dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get spaceL => isSmallScreen ? unit * 4.8 : 24;

  /// Çok büyük boşluk: 32dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get spaceXL => isSmallScreen ? unit * 6.4 : 32;

  /// Aşırı büyük boşluk: 48dp veya ekran genişliğine göre ölçeklendirilmiş değer
  double get spaceXXL => isSmallScreen ? unit * 9.6 : 48;
}

/// Dimensions sınıfına kolay erişim için extension
extension DimensionsExtension on BuildContext {
  /// AppDimensions'a kolay erişim sağlar
  /// Örnek kullanım: context.dimensions.paddingM
  AppDimensions get dimensions => AppDimensions(this);
}
