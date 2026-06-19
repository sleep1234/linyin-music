import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

/// 本地存储服务 —— SQLite 数据库
/// 表：favorites（收藏）、history（播放历史）、url_cache（播放链接缓存）
class StorageService {
  static Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'netease_music.db'),
      version: 4,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS playlists (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              cover_url TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS playlist_songs (
              playlist_id TEXT NOT NULL,
              song_id TEXT NOT NULL,
              source_id TEXT NOT NULL,
              name TEXT NOT NULL,
              artist TEXT NOT NULL DEFAULT '',
              album TEXT NOT NULL DEFAULT '',
              cover_url TEXT,
              url_id TEXT,
              is_vip INTEGER NOT NULL DEFAULT 0,
              duration INTEGER,
              song_json TEXT NOT NULL,
              sort_order INTEGER NOT NULL,
              PRIMARY KEY (playlist_id, song_id, source_id)
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS downloads (
              id TEXT PRIMARY KEY,
              source_id TEXT NOT NULL,
              name TEXT NOT NULL,
              artist TEXT NOT NULL DEFAULT '',
              album TEXT NOT NULL DEFAULT '',
              cover_url TEXT,
              url_id TEXT,
              is_vip INTEGER NOT NULL DEFAULT 0,
              duration INTEGER,
              song_json TEXT NOT NULL,
              file_path TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS lyric_cache (
              song_id TEXT NOT NULL,
              source_id TEXT NOT NULL,
              lyric TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              PRIMARY KEY (song_id, source_id)
            )
          ''');
        }
      },
      onCreate: (db, version) async {
        // 收藏表
        await db.execute('''
          CREATE TABLE favorites (
            id TEXT PRIMARY KEY,
            source_id TEXT NOT NULL,
            name TEXT NOT NULL,
            artist TEXT NOT NULL DEFAULT '',
            album TEXT NOT NULL DEFAULT '',
            cover_url TEXT,
            url_id TEXT,
            is_vip INTEGER NOT NULL DEFAULT 0,
            duration INTEGER,
            song_json TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        // 播放历史
        await db.execute('''
          CREATE TABLE history (
            id TEXT,
            source_id TEXT NOT NULL,
            name TEXT NOT NULL DEFAULT '',
            artist TEXT NOT NULL DEFAULT '',
            album TEXT NOT NULL DEFAULT '',
            cover_url TEXT,
            url_id TEXT,
            is_vip INTEGER NOT NULL DEFAULT 0,
            duration INTEGER,
            song_json TEXT NOT NULL,
            played_at INTEGER NOT NULL,
            PRIMARY KEY (id, source_id)
          )
        ''');
        // 播放链接缓存
        await db.execute('''
          CREATE TABLE url_cache (
            song_id TEXT NOT NULL,
            source_id TEXT NOT NULL,
            quality TEXT NOT NULL,
            url TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (song_id, source_id, quality)
          )
        ''');
        // 本地歌单
        await db.execute('''
          CREATE TABLE playlists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            cover_url TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        // 歌单中的歌曲
        await db.execute('''
          CREATE TABLE playlist_songs (
            playlist_id TEXT NOT NULL,
            song_id TEXT NOT NULL,
            source_id TEXT NOT NULL,
            name TEXT NOT NULL,
            artist TEXT NOT NULL DEFAULT '',
            album TEXT NOT NULL DEFAULT '',
            cover_url TEXT,
            url_id TEXT,
            is_vip INTEGER NOT NULL DEFAULT 0,
            duration INTEGER,
            song_json TEXT NOT NULL,
            sort_order INTEGER NOT NULL,
            PRIMARY KEY (playlist_id, song_id, source_id)
          )
        ''');
        // 下载记录
        await db.execute('''
          CREATE TABLE downloads (
            id TEXT PRIMARY KEY,
            source_id TEXT NOT NULL,
            name TEXT NOT NULL,
            artist TEXT NOT NULL DEFAULT '',
            album TEXT NOT NULL DEFAULT '',
            cover_url TEXT,
            url_id TEXT,
            is_vip INTEGER NOT NULL DEFAULT 0,
            duration INTEGER,
            song_json TEXT NOT NULL,
            file_path TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        // 歌词缓存
        await db.execute('''
          CREATE TABLE lyric_cache (
            song_id TEXT NOT NULL,
            source_id TEXT NOT NULL,
            lyric TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (song_id, source_id)
          )
        ''');
      },
    );
  }

  // ========== 收藏 ==========

  /// 添加收藏
  Future<void> addFavorite(Song song) async {
    final database = await db;
    await database.insert('favorites', {
      'id': song.id,
      'source_id': song.sourceId,
      'name': song.name,
      'artist': song.artist,
      'album': song.album,
      'cover_url': song.coverUrl,
      'url_id': song.urlId,
      'is_vip': song.isVip ? 1 : 0,
      'duration': song.duration?.inMilliseconds,
      'song_json': jsonEncode(song.toJson()),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 移除收藏
  Future<void> removeFavorite(String id, String sourceId) async {
    final database = await db;
    await database.delete('favorites',
        where: 'id = ? AND source_id = ?', whereArgs: [id, sourceId]);
  }

  /// 是否已收藏
  Future<bool> isFavorite(String id, String sourceId) async {
    final database = await db;
    final result = await database.query('favorites',
        where: 'id = ? AND source_id = ?', whereArgs: [id, sourceId]);
    return result.isNotEmpty;
  }

  /// 获取所有收藏
  Future<List<Song>> getFavorites() async {
    final database = await db;
    final results = await database.query('favorites',
        orderBy: 'created_at DESC');
    return results.map(_rowToSong).toList();
  }

  // ========== 播放历史 ==========

  /// 添加播放历史（最多保留200条）
  Future<void> addHistory(Song song) async {
    final database = await db;
    await database.insert('history', {
      'id': song.id,
      'source_id': song.sourceId,
      'name': song.name,
      'artist': song.artist,
      'album': song.album,
      'cover_url': song.coverUrl,
      'url_id': song.urlId,
      'is_vip': song.isVip ? 1 : 0,
      'duration': song.duration?.inMilliseconds,
      'song_json': jsonEncode(song.toJson()),
      'played_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // 保留最近200条
    final count = await database.rawQuery('SELECT COUNT(*) as cnt FROM history');
    final total = count.first['cnt'] as int;
    if (total > 200) {
      final cutoff = await database.rawQuery(
          'SELECT played_at FROM history ORDER BY played_at DESC LIMIT 1 OFFSET 200');
      if (cutoff.isNotEmpty) {
        await database.delete('history',
            where: 'played_at < ?', whereArgs: [cutoff.first['played_at']]);
      }
    }
  }

  /// 获取播放历史
  Future<List<Song>> getHistory({int limit = 50}) async {
    final database = await db;
    final results = await database.query('history',
        orderBy: 'played_at DESC', limit: limit);
    return results.map(_rowToSong).toList();
  }

  /// 清空播放历史
  Future<void> clearHistory() async {
    final database = await db;
    await database.delete('history');
  }

  // ========== URL 缓存 ==========

  /// 缓存播放链接（缓存1小时）
  Future<void> cacheUrl(String songId, String sourceId, String quality, String url) async {
    final database = await db;
    await database.insert('url_cache', {
      'song_id': songId,
      'source_id': sourceId,
      'quality': quality,
      'url': url,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 获取缓存的播放链接（超过1小时视为过期）
  Future<String?> getCachedUrl(String songId, String sourceId, String quality) async {
    final database = await db;
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
    final results = await database.query('url_cache',
        where: 'song_id = ? AND source_id = ? AND quality = ? AND created_at > ?',
        whereArgs: [songId, sourceId, quality, oneHourAgo]);
    if (results.isNotEmpty) return results.first['url'] as String;
    return null;
  }

  /// 清理过期缓存
  Future<void> cleanExpiredCache() async {
    final database = await db;
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
    await database.delete('url_cache', where: 'created_at < ?', whereArgs: [oneHourAgo]);
  }

  // ========== 歌词缓存 ==========

  /// 缓存歌词（永久有效）
  Future<void> cacheLyric(String songId, String sourceId, String lyric) async {
    final database = await db;
    await database.insert('lyric_cache', {
      'song_id': songId,
      'source_id': sourceId,
      'lyric': lyric,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 获取缓存歌词
  Future<String?> getCachedLyric(String songId, String sourceId) async {
    final database = await db;
    final results = await database.query('lyric_cache',
        where: 'song_id = ? AND source_id = ?',
        whereArgs: [songId, sourceId]);
    if (results.isNotEmpty) return results.first['lyric'] as String;
    return null;
  }

  // ========== 工具方法 ==========

  Song _rowToSong(Map<String, dynamic> row) {
    try {
      final json = jsonDecode(row['song_json'] as String) as Map<String, dynamic>;
      return Song.fromJson(json);
    } catch (_) {
      // 降级：从字段构造
      return Song(
        id: row['id'] as String,
        name: row['name'] as String,
        artist: row['artist'] as String,
        album: row['album'] as String,
        coverUrl: row['cover_url'] as String?,
        urlId: row['url_id'] as String?,
        duration: row['duration'] != null
            ? Duration(milliseconds: row['duration'] as int)
            : null,
        sourceId: row['source_id'] as String,
        isVip: (row['is_vip'] as int) == 1,
        filePath: row['file_path'] as String?,
      );
    }
  }

  // ========== 播放列表持久化（SharedPreferences） ==========

  static const _playlistKey = 'player_playlist';
  static const _playlistIndexKey = 'player_playlist_index';

  /// 保存当前播放列表和索引
  Future<void> savePlaylist(List<Song> playlist, int currentIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = playlist.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_playlistKey, jsonList);
    await prefs.setInt(_playlistIndexKey, currentIndex);
  }

  /// 恢复播放列表
  Future<List<Song>> loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_playlistKey);
    if (jsonList == null || jsonList.isEmpty) return [];
    return jsonList.map((str) {
      try {
        return Song.fromJson(jsonDecode(str) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<Song>().toList();
  }

  /// 恢复播放索引
  Future<int> loadPlaylistIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_playlistIndexKey) ?? -1;
  }

  // ========== 本地歌单 ==========

  /// 创建歌单
  Future<String> createPlaylist(String name) async {
    final database = await db;
    final id = 'pl_${DateTime.now().millisecondsSinceEpoch}';
    await database.insert('playlists', {
      'id': id,
      'name': name,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  /// 获取所有歌单（不含歌曲）
  Future<List<Map<String, dynamic>>> getPlaylists() async {
    final database = await db;
    return database.query('playlists', orderBy: 'created_at DESC');
  }

  /// 删除歌单
  Future<void> deletePlaylist(String playlistId) async {
    final database = await db;
    await database.delete('playlist_songs', where: 'playlist_id = ?', whereArgs: [playlistId]);
    await database.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
  }

  /// 重命名歌单
  Future<void> renamePlaylist(String playlistId, String newName) async {
    final database = await db;
    await database.update('playlists', {'name': newName}, where: 'id = ?', whereArgs: [playlistId]);
  }

  /// 向歌单添加歌曲
  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final database = await db;
    // 查当前最大排序号
    final result = await database.rawQuery(
      'SELECT MAX(sort_order) as max_order FROM playlist_songs WHERE playlist_id = ?',
      [playlistId],
    );
    final maxOrder = result.first['max_order'] as int? ?? -1;

    await database.insert('playlist_songs', {
      'playlist_id': playlistId,
      'song_id': song.id,
      'source_id': song.sourceId,
      'name': song.name,
      'artist': song.artist,
      'album': song.album,
      'cover_url': song.coverUrl,
      'url_id': song.urlId,
      'is_vip': song.isVip ? 1 : 0,
      'duration': song.duration?.inMilliseconds,
      'song_json': jsonEncode(song.toJson()),
      'sort_order': maxOrder + 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// 从歌单移除歌曲
  Future<void> removeSongFromPlaylist(String playlistId, String songId, String sourceId) async {
    final database = await db;
    await database.delete('playlist_songs',
        where: 'playlist_id = ? AND song_id = ? AND source_id = ?',
        whereArgs: [playlistId, songId, sourceId]);
  }

  /// 获取歌单中的歌曲
  Future<List<Song>> getPlaylistSongs(String playlistId) async {
    final database = await db;
    final results = await database.query('playlist_songs',
        where: 'playlist_id = ?', whereArgs: [playlistId],
        orderBy: 'sort_order ASC');
    return results.map(_rowToSong).toList();
  }

  /// 获取歌单歌曲数量
  Future<int> getPlaylistSongCount(String playlistId) async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM playlist_songs WHERE playlist_id = ?',
      [playlistId],
    );
    return result.first['cnt'] as int;
  }

  // ========== 下载管理 ==========

  /// 获取下载目录
  Future<String> getDownloadDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = p.join(dir.path, 'downloads');
    await Directory(downloadDir).create(recursive: true);
    return downloadDir;
  }

  /// 保存下载记录
  Future<void> addDownload(Song song, String filePath) async {
    final database = await db;
    await database.insert('downloads', {
      'id': song.id,
      'source_id': song.sourceId,
      'name': song.name,
      'artist': song.artist,
      'album': song.album,
      'cover_url': song.coverUrl,
      'url_id': song.urlId,
      'is_vip': song.isVip ? 1 : 0,
      'duration': song.duration?.inMilliseconds,
      'song_json': jsonEncode(song.toJson()),
      'file_path': filePath,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 获取所有下载
  Future<List<Map<String, dynamic>>> getDownloads() async {
    final database = await db;
    return database.query('downloads', orderBy: 'created_at DESC');
  }

  /// 删除下载记录（同时删除文件）
  Future<void> removeDownload(String id, String sourceId) async {
    final database = await db;
    final results = await database.query('downloads',
        where: 'id = ? AND source_id = ?', whereArgs: [id, sourceId]);
    if (results.isNotEmpty) {
      final filePath = results.first['file_path'] as String;
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    }
    await database.delete('downloads', where: 'id = ? AND source_id = ?', whereArgs: [id, sourceId]);
  }

  /// 检查是否已下载
  Future<bool> isDownloaded(String id, String sourceId) async {
    final database = await db;
    final result = await database.query('downloads',
        where: 'id = ? AND source_id = ?', whereArgs: [id, sourceId]);
    return result.isNotEmpty;
  }

  // ========== 搜索历史 ==========

  static const _searchHistoryKey = 'search_history';

  /// 获取搜索历史（最多30条）
  Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_searchHistoryKey) ?? [];
  }

  /// 添加搜索关键词（去重，新词置顶）
  Future<void> addSearchHistory(String keyword) async {
    if (keyword.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final history = await getSearchHistory();
    history.remove(keyword); // 去重
    history.insert(0, keyword);
    if (history.length > 30) history.removeRange(30, history.length);
    await prefs.setStringList(_searchHistoryKey, history);
  }

  /// 删除单条搜索历史
  Future<void> removeSearchHistory(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getSearchHistory();
    history.remove(keyword);
    await prefs.setStringList(_searchHistoryKey, history);
  }

  /// 清空搜索历史
  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);
  }
}
