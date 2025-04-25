/// Kullanıcı rollerini temsil eden enum
enum UserRole {
  /// Ücretsiz kullanıcı - sınırlı özellikler
  free('free'),

  /// Premium kullanıcı - tüm özellikler
  premium('premium'),

  /// Admin kullanıcı - yönetim özellikleri
  admin('admin');

  /// Role değeri
  final String value;

  /// Constructor
  const UserRole(this.value);

  /// String'ten UserRole oluşturur
  static UserRole fromString(String? value) {
    return switch (value) {
      'premium' => UserRole.premium,
      'admin' => UserRole.admin,
      _ => UserRole.free,
    };
  }

  /// UserRole'ü String'e dönüştürür
  @override
  String toString() => value;

  /// Kullanıcının premium olup olmadığını kontrol eder
  bool get isPremium => this == UserRole.premium || this == UserRole.admin;

  /// Kullanıcının admin olup olmadığını kontrol eder
  bool get isAdmin => this == UserRole.admin;
}
