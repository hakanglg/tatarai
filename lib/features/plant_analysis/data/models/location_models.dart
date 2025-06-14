class Province {
  final int id;
  final String name;

  Province({
    required this.id,
    required this.name,
  });

  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      id: json['ilId'] as int,
      name: json['ilAdi'] as String,
    );
  }
}

class District {
  final String provinceName;
  final String name;

  District({
    required this.provinceName,
    required this.name,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      provinceName: json['ilAdi'] as String,
      name: json['ilceAdi'] as String,
    );
  }
}

class Neighborhood {
  final String provinceName;
  final String districtName;
  final String name;

  Neighborhood({
    required this.provinceName,
    required this.districtName,
    required this.name,
  });

  factory Neighborhood.fromJson(Map<String, dynamic> json) {
    return Neighborhood(
      provinceName: json['ilAdi'] as String,
      districtName: json['ilceAdi'] as String,
      name: json['mahalleAdi'] as String,
    );
  }
}
