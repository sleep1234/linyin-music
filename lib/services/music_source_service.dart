import 'dart:convert';
import 'dart:collection';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/models.dart';
import 'storage_service.dart';

/// 音乐源服务 - 多源聚合搜索 + URL缓存
/// 搜索/播放链接/歌词/封面 → GET + music-api.gdstudio.xyz
/// 排行榜/歌单导入 → POST + music.gdstudio.org
class MusicSourceService extends ChangeNotifier {
  static const String _apiGet = 'https://music-api.gdstudio.xyz/api.php';
  static const String _apiPost = 'https://music.gdstudio.org/api.php';

  static const List<Map<String, String>> _sources = [
    {'id': 'netease', 'name': '网易云', 'icon': '🎵'},
    {'id': 'kuwo', 'name': '酷我', 'icon': '🎸'},
    {'id': 'tencent', 'name': 'QQ音乐', 'icon': '🎶'},
    {'id': 'bilibili', 'name': 'B站', 'icon': '📺'},
    {'id': 'joox', 'name': 'JOOX', 'icon': '🎤'},
  ];

  final StorageService _storage;

  // 搜索结果内存缓存（关键词 → 结果，最多缓存20条）
  final LinkedHashMap<String, List<Song>> _searchCache = LinkedHashMap();
  static const int _maxSearchCache = 20;

  // 排行榜内存缓存（id → 结果）
  final Map<int, List<Song>> _rankCache = {};

  MusicSourceService(this._storage);

  /// GET 请求（搜索、播放链接、歌词、封面）
  Future<http.Response> _get(String query) async {
    final uri = Uri.parse('$_apiGet?$query');
    return http.get(uri).timeout(const Duration(seconds: 15));
  }

  /// POST 请求（排行榜、歌单导入）
  Future<http.Response> _post(String body) async {
    final uri = Uri.parse(_apiPost);
    return http.post(uri, headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    }, body: body).timeout(const Duration(seconds: 15));
  }

  /// 构造带 s 参数的查询字符串
  String _buildQuery(String mainKey, String mainValue, [Map<String, String>? extra]) {
    final s = getCrc32(mainValue.codeUnits);
    final parts = [mainKey, '=', Uri.encodeComponent(mainValue), '&s=', s.toString()];
    if (extra != null) {
      for (final e in extra.entries) {
        parts.addAll(['&', e.key, '=', e.value]);
      }
    }
    return parts.join();
  }

  /// 多源搜索 - 并发搜索所有音源，合并去重（带内存缓存）
  Future<List<Song>> search(String keyword) async {
    if (keyword.trim().isEmpty) return [];

    final key = keyword.trim().toLowerCase();

    // 查缓存
    if (_searchCache.containsKey(key)) {
      return _searchCache[key]!;
    }

    final futures = _sources.map((s) => _searchSource(s['id']!, keyword)).toList();
    final results = await Future.wait(futures, eagerError: false);

    final List<Song> merged = [];
    final Set<String> seen = {};

    for (final songs in results) {
      for (final song in songs) {
        final songKey = '${song.id}_${song.sourceId}';
        if (!seen.contains(songKey)) {
          seen.add(songKey);
          merged.add(song);
        }
      }
    }

    // 写入缓存（超出上限则移除最早的）
    if (_searchCache.length >= _maxSearchCache) {
      _searchCache.remove(_searchCache.keys.first);
    }
    _searchCache[key] = merged;

    return merged;
  }

  /// 单源搜索
  Future<List<Song>> _searchSource(String sourceId, String keyword) async {
    try {
      final res = await _get(_buildQuery('name', keyword, {
        'types': 'search',
        'count': '30',
        'pages': '1',
        'source': sourceId,
      }));

      if (res.statusCode != 200) {
        debugPrint('[搜索] $sourceId 返回 ${res.statusCode}');
        return [];
      }

      final data = jsonDecode(res.body);
      if (data is! List) return [];

      return data.map<Song>((item) {
        final artist = item['artist'];
        final artistStr = artist is List ? artist.join(' / ') : artist?.toString() ?? '';
        final picId = item['pic_id']?.toString();

        return Song(
          id: item['id']?.toString() ?? '',
          name: item['name'] ?? '',
          artist: artistStr,
          album: item['album'] ?? '',
          coverUrl: picId,
          urlId: item['url_id']?.toString(),
          // API可能返回 extra_data.duration (秒)
          duration: item['extra_data']?['duration'] != null
              ? Duration(seconds: item['extra_data']['duration'] as int)
              : null,
          sourceId: sourceId,
          isVip: item['vip'] == 1 || item['vip'] == true,
        );
      }).toList();
    } catch (e) {
      debugPrint('[搜索] $sourceId 失败: $e');
      return [];
    }
  }

  /// 获取播放链接（支持自动换源 + URL缓存）
  Future<String?> getSongUrl(Song song, {AudioQuality quality = AudioQuality.high}) async {
    final br = _getBitrate(quality);
    final playId = song.urlId ?? song.id;
    final cacheKey = song.id;

    // 1. 先查缓存
    final cached = await _storage.getCachedUrl(cacheKey, song.sourceId, br);
    if (cached != null) {
      debugPrint('[缓存] 命中: ${song.name}');
      return cached;
    }

    // 2. 尝试当前音源
    final url = await _fetchUrl(playId, song.sourceId, br);
    if (url != null && url.isNotEmpty) {
      await _storage.cacheUrl(cacheKey, song.sourceId, br, url);
      return url;
    }

    // 3. 当前音源失败，尝试其他音源
    for (final source in _sources) {
      if (source['id'] == song.sourceId) continue;
      final altUrl = await _fetchUrl(playId, source['id']!, br);
      if (altUrl != null && altUrl.isNotEmpty) {
        await _storage.cacheUrl(cacheKey, source['id']!, br, altUrl);
        return altUrl;
      }
    }

    return null;
  }

  Future<String?> _fetchUrl(String id, String source, String br) async {
    try {
      final res = await _get(_buildQuery('id', id, {
        'types': 'url',
        'source': source,
        'br': br,
      }));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final playUrl = data['url'];
      if (playUrl != null && playUrl.toString().isNotEmpty) return playUrl;
      return null;
    } catch (e) {
      debugPrint('[播放链接] $source 失败: $e');
      return null;
    }
  }

  /// 获取歌词
  Future<String?> getLyric(Song song) async {
    try {
      final res = await _get(_buildQuery('id', song.id, {
        'types': 'lyric',
        'source': song.sourceId,
      }));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      return data['lyric'];
    } catch (e) {
      return null;
    }
  }

  /// 获取封面图片（通过 pic_id）
  Future<String?> getCover(String picId, String sourceId) async {
    try {
      final res = await _get(_buildQuery('id', picId, {
        'types': 'pic',
        'source': sourceId,
      }));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      return data['url'];
    } catch (e) {
      return null;
    }
  }

  String _getBitrate(AudioQuality quality) {
    switch (quality) {
      case AudioQuality.low: return '128';
      case AudioQuality.medium: return '192';
      case AudioQuality.high: return '320';
      case AudioQuality.lossless: return '999';
      case AudioQuality.hires: return '999';
    }
  }

  /// 获取排行榜 — 直接调网易云官方API
  /// 热歌榜=3778678, 新歌榜=3779629, 飙升榜=19723756
  /// 古典榜=71384707, 电音榜=1978921795, ACG榜=71385702
  /// 欧美榜=2809513713, 日语榜=5059644681, 韩语榜=745956260
  Future<List<Song>> getNeteaseRank({int id = 3778678, int count = 30}) async {
    // 查缓存
    if (_rankCache.containsKey(id)) {
      return _rankCache[id]!;
    }

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final uri = Uri.parse('https://music.163.com/api/v6/playlist/detail?id=$id');
        final res = await http.get(uri, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://music.163.com',
        }).timeout(const Duration(seconds: 15));

        if (res.statusCode != 200) {
          debugPrint('[排行榜] 第${attempt+1}次返回 ${res.statusCode}');
          if (attempt < 2) {
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          return [];
        }
        final data = jsonDecode(res.body);
        if (data['code'] != 200) {
          debugPrint('[排行榜] 第${attempt+1}次 code=${data['code']}');
          if (attempt < 2) {
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          return [];
        }
        final tracks = data['playlist']?['tracks'] as List?;
        if (tracks == null || tracks.isEmpty) {
          debugPrint('[排行榜] 第${attempt+1}次 tracks 为空');
          if (attempt < 2) {
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          return [];
        }

        final songs = tracks.take(count).map<Song>((item) {
          final artists = item['ar'] as List? ?? item['artists'] as List? ?? [];
          final album = item['al'] ?? item['album'] ?? {};
          return Song(
            id: item['id']?.toString() ?? '',
            name: item['name'] ?? '',
            artist: artists.map((a) => a['name'] ?? '').join(' / '),
            artistId: artists.isNotEmpty ? (artists[0]['id']?.toString() ?? '') : '',
            album: album['name'] ?? '',
            albumId: album['id']?.toString() ?? '',
            coverUrl: album['picUrl'],
            urlId: item['id']?.toString(),
            duration: item['dt'] != null
                ? Duration(milliseconds: item['dt'] as int)
                : item['duration'] != null
                    ? Duration(milliseconds: item['duration'] as int)
                    : null,
            sourceId: 'netease',
            isVip: (item['fee'] ?? 0) == 1,
          );
        }).toList();

        // 写入缓存
        _rankCache[id] = songs;
        return songs;
      } catch (e) {
        debugPrint('[排行榜] 第${attempt+1}次失败: $e');
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        return [];
      }
    }
    return [];
  }

  /// 导入网易云用户歌单列表（直接调网易云API）
  Future<List<Map<String, dynamic>>> getUserPlaylists(String uid) async {
    try {
      final uri = Uri.parse('https://music.163.com/api/user/playlist?uid=$uid&limit=50&offset=0');
      final res = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://music.163.com',
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      if (data['code'] != 200) return [];
      final list = data['playlist'] as List? ?? [];
      return list.map((item) => <String, dynamic>{
        'id': item['id']?.toString() ?? '',
        'name': item['name'] ?? '',
        'coverUrl': item['coverImgUrl'] ?? '',
        'creator': item['creator']?['nickname'] ?? '',
        'trackCount': item['trackCount'] ?? 0,
      }).toList();
    } catch (e) {
      debugPrint('[用户歌单] 获取失败: $e');
      return [];
    }
  }

  // ========== 歌单导入 ==========

  /// 解析分享链接，返回 {platform, id}
  static Map<String, String>? parseShareUrl(String url) {
    // 网易云: https://y.music.163.com/m/playlist?id=2155647668
    //         https://music.163.com/playlist?id=2155647668
    final neteaseMatch = RegExp(r'music\.163\.com.*[?&]id=(\d+)').firstMatch(url);
    if (neteaseMatch != null) {
      return {'platform': 'netease', 'id': neteaseMatch.group(1)!};
    }

    // 汽水音乐: https://qishui.douyin.com/s/xxx 或 ?playlist_id=xxx
    final qishuiShortMatch = RegExp(r'qishui\.douyin\.com/s/(\w+)').firstMatch(url);
    if (qishuiShortMatch != null) {
      return {'platform': 'qishui', 'id': qishuiShortMatch.group(1)!, 'type': 'short'};
    }
    final qishuiMatch = RegExp(r'qishui\.douyin\.com.*[?&]playlist_id=(\d+)').firstMatch(url);
    if (qishuiMatch != null) {
      return {'platform': 'qishui', 'id': qishuiMatch.group(1)!};
    }

    return null;
  }

  /// 获取网易云歌单歌曲列表
  Future<List<Map<String, String>>> fetchNeteasePlaylist(String id) async {
    try {
      final uri = Uri.parse('https://music.163.com/api/v6/playlist/detail?id=$id');
      final res = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://music.163.com',
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      if (data['code'] != 200) return [];
      final tracks = data['playlist']?['tracks'] as List? ?? [];
      return tracks.map<Map<String, String>>((t) {
        final artists = t['ar'] as List? ?? [];
        return {
          'name': t['name']?.toString() ?? '',
          'artist': artists.map((a) => a['name'] ?? '').join(' / '),
        };
      }).toList();
    } catch (e) {
      debugPrint('[网易云歌单] 获取失败: $e');
      return [];
    }
  }

  /// 获取汽水音乐歌单歌曲列表（从HTML SSR数据提取）
  Future<List<Map<String, String>>> fetchQishuiPlaylist(String playlistId) async {
    try {
      final url = 'https://qishui.douyin.com/playlist?playlist_id=$playlistId';
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];

      final html = res.body;
      // 提取 _ROUTER_DATA
      final match = RegExp(r'_ROUTER_DATA\s*=\s*').firstMatch(html);
      if (match == null) return [];

      final start = match.end;
      int depth = 0;
      int end = start;
      for (int i = start; i < html.length; i++) {
        if (html[i] == '{') depth++;
        else if (html[i] == '}') {
          depth--;
          if (depth == 0) { end = i + 1; break; }
        }
      }

      final jsonData = jsonDecode(html.substring(start, end));
      final medias = jsonData['loaderData']?['playlist_page']?['medias'] as List? ?? [];

      final List<Map<String, String>> songs = [];
      for (final media in medias) {
        final entity = media['entity'] ?? {};
        final track = entity['track'];
        if (track == null) continue;

        final name = track['name']?.toString() ?? '';
        final artists = track['artists'] as List? ?? [];
        final artistNames = artists
            .whereType<Map<String, dynamic>>()
            .map((a) => a['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .join(' / ');

        if (name.isNotEmpty) {
          songs.add({'name': name, 'artist': artistNames});
        }
      }

      return songs;
    } catch (e) {
      debugPrint('[汽水音乐歌单] 获取失败: $e');
      return [];
    }
  }

  /// 导入歌单：解析URL → 获取歌曲列表 → 在多源中搜索匹配 → 返回匹配的歌曲
  /// callback 用于报告进度
  Future<List<Song>> importPlaylist(
    String url, {
    void Function(int current, int total, String songName)? onProgress,
  }) async {
    final parsed = parseShareUrl(url);
    if (parsed == null) {
      debugPrint('[歌单导入] 无法识别链接: $url');
      return [];
    }

    // 获取原始歌曲列表
    List<Map<String, String>> rawSongs;
    if (parsed['platform'] == 'netease') {
      rawSongs = await fetchNeteasePlaylist(parsed['id']!);
    } else if (parsed['platform'] == 'qishui') {
      if (parsed['type'] == 'short') {
        // 短链接需要先跟随重定向获取 playlist_id
        final playlistId = await _resolveQishuiShortUrl(parsed['id']!);
        if (playlistId == null) return [];
        rawSongs = await fetchQishuiPlaylist(playlistId);
      } else {
        rawSongs = await fetchQishuiPlaylist(parsed['id']!);
      }
    } else {
      return [];
    }

    if (rawSongs.isEmpty) return [];

    debugPrint('[歌单导入] 获取到 ${rawSongs.length} 首歌曲，开始多源匹配...');

    // 逐首搜索匹配
    final List<Song> matched = [];
    for (int i = 0; i < rawSongs.length; i++) {
      final s = rawSongs[i];
      final keyword = ((s['artist'] ?? '').isNotEmpty) ? '${s['name']} ${s['artist']}' : '${s['name']}';
      onProgress?.call(i + 1, rawSongs.length, s['name'] ?? '');

      try {
        final results = await search(keyword);
        if (results.isNotEmpty) {
          // 取第一个匹配的
          matched.add(results.first);
        }
      } catch (_) {}

      // 避免请求过快
      if (i % 5 == 4) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    debugPrint('[歌单导入] 匹配完成: ${matched.length}/${rawSongs.length}');
    return matched;
  }

  /// 解析汽水音乐短链接获取 playlist_id
  Future<String?> _resolveQishuiShortUrl(String shortCode) async {
    try {
      final res = await http.get(
        Uri.parse('https://qishui.douyin.com/s/$shortCode'),
        headers: {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'},
      ).timeout(const Duration(seconds: 10));
      // 跟随重定向后的URL中提取 playlist_id
      final finalUrl = res.request?.url?.toString() ?? '';
      final match = RegExp(r'playlist_id=(\d+)').firstMatch(finalUrl);
      if (match != null) return match.group(1);
      // 也检查 body
      final bodyMatch = RegExp(r'playlist_id=(\d+)').firstMatch(res.body);
      if (bodyMatch != null) return bodyMatch.group(1);
    } catch (e) {
      debugPrint('[汽水短链] 解析失败: $e');
    }
    return null;
  }
}
