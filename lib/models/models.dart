/// 歌曲模型
class Song {
  final String id;
  final String name;
  final String artist;
  final String artistId;
  final String album;
  final String albumId;
  String? coverUrl; // 可变：初始存 pic_id，获取后替换为真实 URL
  final String? urlId; // 用于获取播放链接的ID
  final Duration? duration;
  final String sourceId; // 来源平台
  final bool isVip;
  final Map<String, String>? urlCache; // 不同音质的URL缓存
  final String? filePath; // 本地文件路径（下载的歌曲）

  Song({
    required this.id,
    required this.name,
    required this.artist,
    this.artistId = '',
    this.album = '',
    this.albumId = '',
    this.coverUrl,
    this.urlId,
    this.duration,
    required this.sourceId,
    this.isVip = false,
    this.urlCache,
    this.filePath,
  });

  String get durationText {
    if (duration == null) return '00:00';
    final min = duration!.inMinutes;
    final sec = duration!.inSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      artist: json['artist'] ?? json['ar']?[0]?['name'] ?? '',
      artistId: json['artistId']?.toString() ?? json['ar']?[0]?['id']?.toString() ?? '',
      album: json['album'] ?? json['al']?['name'] ?? '',
      albumId: json['albumId']?.toString() ?? json['al']?['id']?.toString() ?? '',
      coverUrl: json['coverUrl'] ?? json['al']?['picUrl'],
      urlId: json['urlId']?.toString(),
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : json['dt'] != null
              ? Duration(milliseconds: json['dt'] as int)
              : null,
      sourceId: json['sourceId'] ?? 'netease',
      isVip: json['vip'] ?? json['fee'] == 1,
      filePath: json['filePath']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'artist': artist,
    'artistId': artistId,
    'album': album,
    'albumId': albumId,
    'coverUrl': coverUrl,
    'urlId': urlId,
    'duration': duration?.inMilliseconds,
    'sourceId': sourceId,
    'vip': isVip,
    'filePath': filePath,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id && sourceId == other.sourceId;

  @override
  int get hashCode => id.hashCode ^ sourceId.hashCode;
}

/// 歌单模型
class Playlist {
  final String id;
  final String name;
  final String? coverUrl;
  final String creator;
  final int songCount;
  final String sourceId;
  final List<Song>? songs;

  Playlist({
    required this.id,
    required this.name,
    this.coverUrl,
    this.creator = '',
    this.songCount = 0,
    required this.sourceId,
    this.songs,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      coverUrl: json['coverUrl'] ?? json['coverImgUrl'],
      creator: json['creator']?['nickname'] ?? '',
      songCount: json['trackCount'] ?? json['songCount'] ?? 0,
      sourceId: json['sourceId'] ?? 'netease',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'coverUrl': coverUrl,
    'creator': creator,
    'trackCount': songCount,
    'sourceId': sourceId,
  };
}

/// 歌手模型
class Artist {
  final String id;
  final String name;
  final String? avatarUrl;
  final String sourceId;

  Artist({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.sourceId,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['picUrl'] ?? json['avatarUrl'],
      sourceId: json['sourceId'] ?? 'netease',
    );
  }
}

/// 搜索结果
class SearchResult {
  final List<Song> songs;
  final List<Playlist> playlists;
  final List<Artist> artists;
  final int totalCount;

  SearchResult({
    required this.songs,
    required this.playlists,
    required this.artists,
    required this.totalCount,
  });
}

/// 每日推荐
class DailyRecommend {
  final String date;
  final List<Song> songs;
  final String reason; // 推荐理由

  DailyRecommend({
    required this.date,
    required this.songs,
    this.reason = '',
  });
}
