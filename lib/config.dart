/// 音乐源配置
class MusicSource {
  final String id;
  final String name;
  final String icon;
  final String baseUrl;
  final bool isActive;

  const MusicSource({
    required this.id,
    required this.name,
    required this.icon,
    required this.baseUrl,
    this.isActive = true,
  });

  factory MusicSource.fromJson(Map<String, dynamic> json) {
    return MusicSource(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '🎵',
      baseUrl: json['baseUrl'] ?? '',
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'baseUrl': baseUrl,
    'isActive': isActive,
  };
}

/// 音质等级
enum AudioQuality {
  low,      // 128kbps
  medium,   // 192kbps
  high,     // 320kbps
  lossless, // FLAC 无损
  hires,    // Hi-Res
}

extension AudioQualityExtension on AudioQuality {
  String get label {
    switch (this) {
      case AudioQuality.low: return '标准 128K';
      case AudioQuality.medium: return '较高 192K';
      case AudioQuality.high: return '极高 320K';
      case AudioQuality.lossless: return '无损 FLAC';
      case AudioQuality.hires: return 'Hi-Res';
    }
  }

  String get shortLabel {
    switch (this) {
      case AudioQuality.low: return '128K';
      case AudioQuality.medium: return '192K';
      case AudioQuality.high: return '320K';
      case AudioQuality.lossless: return 'FLAC';
      case AudioQuality.hires: return 'Hi-Res';
    }
  }
}
