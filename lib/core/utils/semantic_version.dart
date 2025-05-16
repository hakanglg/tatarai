/// Semantik sürüm numaralarını temsil eden ve karşılaştıran sınıf
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;
  final String? build;
  final String? preRelease;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build,
    this.preRelease,
  });

  /// '1.2.3' veya '1.2.3-beta+001' gibi versiyonları ayrıştırır
  factory SemanticVersion.fromString(String version) {
    String versionCore = version;
    String? buildMetadata;
    String? preRelease;

    // build kısmını ayır
    if (version.contains('+')) {
      final parts = version.split('+');
      versionCore = parts[0];
      buildMetadata = parts.length > 1 ? parts[1] : null;
    }

    // pre-release kısmını ayır
    if (versionCore.contains('-')) {
      final parts = versionCore.split('-');
      versionCore = parts[0];
      preRelease = parts.length > 1 ? parts[1] : null;
    }

    final segments = versionCore.split('.');
    if (segments.length < 3) {
      throw FormatException('Geçersiz semantik sürüm formatı: $version');
    }

    return SemanticVersion(
      major: int.tryParse(segments[0]) ?? 0,
      minor: int.tryParse(segments[1]) ?? 0,
      patch: int.tryParse(segments[2]) ?? 0,
      build: buildMetadata,
      preRelease: preRelease,
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major - other.major;
    if (minor != other.minor) return minor - other.minor;
    if (patch != other.patch) return patch - other.patch;
    return 0; // build ve prerelease dikkate alınmaz
  }

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch;

  @override
  int get hashCode => major.hashCode ^ minor.hashCode ^ patch.hashCode;
}
