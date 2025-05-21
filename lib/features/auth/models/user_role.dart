/// Kullanıcı rollerini temsil eden enum
enum UserRole {
  /// Ücretsiz kullanıcı - sınırlı özellikler
  free('free'),

  /// Premium kullanıcı - tüm özellikler
  premium('premium'),

  /// Admin kullanıcı - yönetim özellikleri
  admin('admin'),

  /// Editor kullanıcı - editör özellikleri
  editor('editor'),

  /// Destek kullanıcı - destek özellikleri
  support('support');

  /// Role değeri
  final String value;

  /// Constructor
  const UserRole(this.value);

  /// String'ten UserRole oluşturur
  static UserRole fromString(String? roleString) {
    if (roleString == null) return UserRole.free;
    return UserRole.values.firstWhere(
      (role) => role.value == roleString.toLowerCase(),
      orElse: () => UserRole.free,
    );
  }

  /// UserRole'ü String'e dönüştürür
  @override
  String toString() => value;

  /// Kullanıcının admin olup olmadığını kontrol eder
  bool get isAdmin => this == UserRole.admin;
}
