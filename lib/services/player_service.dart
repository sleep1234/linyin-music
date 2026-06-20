import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../models/models.dart';
import '../config.dart';
import '../utils/lrc_parser.dart';
import 'music_source_service.dart';
import 'storage_service.dart';

/// 播放状态
enum PlayMode {
  sequential,
  loop,
  singleLoop,
  shuffle,
}

  /// 播放器服务 —— 集成 audio_service + 歌词同步 + 历史/收藏
class PlayerService extends ChangeNotifier {
  final MusicSourceService _sourceService;
  final StorageService _storage;
  final AudioPlayer _player = AudioPlayer();
  AudioHandler? _handler;
  bool _initStarted = false;
  bool _handlerReady = false;
  bool _isLoading = false;
  int _savedPositionMs = 0;

  // CarPlay 通信
  static const _carplayChannel = MethodChannel('com.xiaopeng.netease_music/carplay');

  bool get isLoading => _isLoading;

  AudioPlayer get player => _player;

  List<Song> _playlist = [];
  int _currentIndex = -1;
  PlayMode _playMode = PlayMode.sequential;
  AudioQuality _quality = AudioQuality.high;
  bool _isVipMode = true;

  // 歌词相关
  List<LrcLine> _lrcLines = [];
  int _currentLrcIndex = -1;
  StreamSubscription<Duration>? _positionSub;
  Timer? _lyricTimer;
  Timer? _positionSaveTimer;

  // 收藏状态（内存缓存，避免频繁查库）
  Set<String> _favoriteIds = {};

  List<LrcLine> get lrcLines => _lrcLines;
  int get currentLrcIndex => _currentLrcIndex;

  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _playlist.length
      ? _playlist[_currentIndex]
      : null;
  PlayMode get playMode => _playMode;
  AudioQuality get quality => _quality;
  bool get isVipMode => _isVipMode;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<bool> get playingStream => _player.playingStream;

  PlayerService(this._sourceService, this._storage) {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onSongComplete();
      }
      notifyListeners();
    });
    _initHandler();
    _startLyricSync();
    _startPositionSave();
    _loadFavorites(); // 启动时加载收藏ID集合
    _restorePlaylist(); // 启动时恢复播放列表
    _initCarPlay(); // 初始化 CarPlay 通信
  }

  /// 初始化 CarPlay MethodChannel
  void _initCarPlay() {
    _carplayChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'playSong':
          final index = call.arguments as int;
          if (index >= 0 && index < _playlist.length) {
            play(_playlist[index]);
          }
          break;
        case 'togglePlay':
          togglePlay();
          break;
        case 'next':
          next();
          break;
        case 'previous':
          previous();
          break;
        case 'toggleFavorite':
          final song = currentSong;
          if (song != null) toggleFavorite(song);
          break;
      }
      return null;
    });
  }

  /// 同步播放列表到 CarPlay
  void _syncToCarPlay() {
    try {
      final songData = _playlist.map((s) => {
        'name': s.name,
        'artist': s.artist,
        'id': s.id,
        'sourceId': s.sourceId,
      }).toList();
      _carplayChannel.invokeMethod('updatePlaylist', {
        'songs': songData,
        'currentIndex': _currentIndex,
      });
    } catch (_) {}
  }

  /// 从数据库加载收藏ID集合
  Future<void> _loadFavorites() async {
    final favs = await _storage.getFavorites();
    _favoriteIds = favs.map((s) => '${s.id}_${s.sourceId}').toSet();
    notifyListeners();
  }

  /// 判断歌曲是否已收藏
  bool isFavorite(Song song) => _favoriteIds.contains('${song.id}_${song.sourceId}');

  /// 切换收藏状态（乐观更新）
  Future<void> toggleFavorite(Song song) async {
    final key = '${song.id}_${song.sourceId}';
    final wasFavorite = _favoriteIds.contains(key);
    // 先更新内存状态，立即反映到 UI
    if (wasFavorite) {
      _favoriteIds.remove(key);
    } else {
      _favoriteIds.add(key);
    }
    notifyListeners();
    // 异步写库
    try {
      if (wasFavorite) {
        await _storage.removeFavorite(song.id, song.sourceId);
      } else {
        await _storage.addFavorite(song);
      }
    } catch (_) {
      // 写库失败，回滚
      if (wasFavorite) {
        _favoriteIds.add(key);
      } else {
        _favoriteIds.remove(key);
      }
      notifyListeners();
    }
  }

  /// 启动时恢复上次的播放列表
  Future<void> _restorePlaylist() async {
    final songs = await _storage.loadPlaylist();
    final index = await _storage.loadPlaylistIndex();
    final position = await _storage.loadPosition();
    if (songs.isNotEmpty && index >= 0 && index < songs.length) {
      _playlist = songs;
      _currentIndex = index;
      _savedPositionMs = position;
      notifyListeners();
    }
  }

  /// 保存当前播放列表到本地
  void _savePlaylist() {
    _storage.savePlaylist(_playlist, _currentIndex);
    _syncToCarPlay();
    // 同步 queue 到 audio_service（供 Android Auto / CarWith 浏览）
    if (_handlerReady) {
      (_handler as _MusicAudioHandler).syncQueue(_playlist);
    }
  }

  Future<void> _initHandler() async {
    if (_initStarted) return;
    _initStarted = true;
    try {
      _handler = await AudioService.init(
        builder: () => _MusicAudioHandler(playerService: this, player: _player),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.xiaopeng.netease_music.audio',
          androidNotificationChannelName: '音乐播放',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
      _handlerReady = true;
    } catch (e) {
      print('[AudioService] init failed: $e');
    }
  }

  /// 更新系统媒体信息
  void _updateMediaItem({String? title, String? subtitle}) {
    final song = currentSong;
    if (song == null || _handler == null) return;

    final displayTitle = title ?? song.name;
    final displaySubtitle = subtitle ?? song.artist;

    final h = _handler as _MusicAudioHandler;
    h.mediaItem.add(MediaItem(
      id: song.id,
      album: song.album,
      title: displayTitle,
      artist: displaySubtitle,
      duration: _player.duration,
      artUri: (song.coverUrl != null && song.coverUrl!.startsWith('http'))
          ? Uri.parse(song.coverUrl!)
          : (song.coverUrl != null && File(song.coverUrl!).existsSync())
              ? Uri.file(song.coverUrl!)
              : null,
    ));
  }

  /// 播放歌曲
  Future<void> play(Song song, {List<Song>? playlist, int? index}) async {
    if (!_handlerReady) await _initHandler();

    if (playlist != null) {
      _playlist = List.from(playlist);
      _currentIndex = index ?? playlist.indexOf(song);
    } else {
      final idx = _playlist.indexOf(song);
      if (idx >= 0) {
        _currentIndex = idx;
      } else {
        _playlist.add(song);
        _currentIndex = _playlist.length - 1;
      }
    }

    // 显示加载状态
    _isLoading = true;
    notifyListeners();

    String? url;

    // 优先使用本地文件路径（下载的歌曲）
    if (song.filePath != null) {
      final file = File(song.filePath!);
      if (await file.exists()) {
        url = song.filePath;
      }
    }

    // 本地文件不存在或非下载歌曲，走网络
    if (url == null) {
      url = await _sourceService.getSongUrl(song, quality: _quality);
    }

    if (url == null) {
      _isLoading = false;
      notifyListeners();
      // URL获取失败，自动跳下一首
      if (_playlist.length > 1) {
        await Future.delayed(const Duration(milliseconds: 300));
        next();
      }
      return;
    }

    // 清空旧歌词
    _lrcLines = [];
    _currentLrcIndex = -1;

    // 先推一次基础媒体信息
    _updateMediaItem();

    try {
      await _player.setUrl(url);
      if (_savedPositionMs > 0) {
        await _player.seek(Duration(milliseconds: _savedPositionMs));
        _savedPositionMs = 0;
      }
      _player.play();
    } catch (e) {
      print('[PlayerService] 播放失败: $e');
      // 播放失败自动跳下一首
      if (_playlist.length > 1) {
        await Future.delayed(const Duration(milliseconds: 500));
        next();
      }
      return;
    }

    // 加载完成
    _isLoading = false;

    // 播放后获取时长
    final dur = _player.duration;
    if (dur != null && song.duration == null) {
      final idx = _playlist.indexOf(song);
      if (idx >= 0) {
        _playlist[idx] = Song(
          id: song.id, name: song.name, artist: song.artist,
          artistId: song.artistId, album: song.album, albumId: song.albumId,
          coverUrl: song.coverUrl, urlId: song.urlId, duration: dur,
          sourceId: song.sourceId, isVip: song.isVip, urlCache: song.urlCache,
        );
      }
    }

    // 异步获取歌词
    _fetchLyric(song);

    // 记录播放历史（不阻塞播放）
    _storage.addHistory(song);

    _savePlaylist();
    notifyListeners();
  }

  /// 获取歌词（优先缓存）
  Future<void> _fetchLyric(Song song) async {
    try {
      // 1. 先查缓存
      String? lrcText = await _storage.getCachedLyric(song.id, song.sourceId);

      // 2. 缓存没有则请求API
      if (lrcText == null || lrcText.isEmpty) {
        lrcText = await _sourceService.getLyric(song);
        // 写入缓存
        if (lrcText != null && lrcText.isNotEmpty) {
          await _storage.cacheLyric(song.id, song.sourceId, lrcText);
        }
      }

      if (lrcText != null && lrcText.isNotEmpty) {
        final lines = LrcParser.parse(lrcText);
        if (lines.isNotEmpty) {
          _lrcLines = lines;
          _currentLrcIndex = -1;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// 启动歌词同步定时器（每200ms检查一次）
  void _startLyricSync() {
    _lyricTimer?.cancel();
    _lyricTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _syncLyric();
    });
  }

  /// 每5秒保存一次播放进度
  void _startPositionSave() {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_player.playing && _player.position.inMilliseconds > 0) {
        _storage.savePosition(_player.position.inMilliseconds);
      }
    });
  }

  /// 同步当前歌词行
  void _syncLyric() {
    if (_lrcLines.isEmpty) return;
    if (!_player.playing) return;

    final pos = _player.position;
    final newIdx = LrcParser.findCurrentLine(_lrcLines, pos);

    if (newIdx != _currentLrcIndex && newIdx >= 0) {
      _currentLrcIndex = newIdx;
      final lrcText = _lrcLines[newIdx].text;

      final song = currentSong;
      if (song != null && _handlerReady) {
        _updateMediaItem(
          title: lrcText,
          subtitle: '${song.artist} - ${song.name}',
        );
      }

      notifyListeners();
    } else if (newIdx < 0 && _currentLrcIndex >= 0) {
      _currentLrcIndex = -1;
      _updateMediaItem();
      notifyListeners();
    }
  }

  /// 获取当前歌词文本（供外部UI使用）
  String? get currentLyricText {
    if (_currentLrcIndex >= 0 && _currentLrcIndex < _lrcLines.length) {
      return _lrcLines[_currentLrcIndex].text;
    }
    return null;
  }

  void togglePlay() {
    if (_player.playing) {
      _player.pause();
    } else if (_player.processingState == ProcessingState.idle && currentSong != null) {
      play(currentSong!);
    } else {
      _player.play();
    }
  }

  void pause() => _player.pause();
  void resume() => _player.play();

  void previous() {
    if (_playlist.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    play(_playlist[_currentIndex]);
  }

  void next() {
    if (_playlist.isEmpty) return;
    switch (_playMode) {
      case PlayMode.shuffle:
        _currentIndex = (_playlist.length * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000).toInt() % _playlist.length;
        break;
      case PlayMode.singleLoop:
        break;
      default:
        _currentIndex = (_currentIndex + 1) % _playlist.length;
    }
    play(_playlist[_currentIndex]);
  }

  Future<void> seek(Duration position) async => _player.seek(position);

  void togglePlayMode() {
    switch (_playMode) {
      case PlayMode.sequential: _playMode = PlayMode.loop; break;
      case PlayMode.loop: _playMode = PlayMode.singleLoop; break;
      case PlayMode.singleLoop: _playMode = PlayMode.shuffle; break;
      case PlayMode.shuffle: _playMode = PlayMode.sequential; break;
    }
    notifyListeners();
  }

  void setQuality(AudioQuality quality) { _quality = quality; notifyListeners(); }
  void toggleVipMode() { _isVipMode = !_isVipMode; notifyListeners(); }

  void _onSongComplete() => next();

  void clearPlaylist() {
    _playlist.clear();
    _currentIndex = -1;
    _lrcLines = [];
    _currentLrcIndex = -1;
    _player.stop();
    _savePlaylist();
    notifyListeners();
  }

  void removeSong(int index) {
    if (index < 0 || index >= _playlist.length) return;
    _playlist.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_playlist.isEmpty) {
        _currentIndex = -1;
        _player.stop();
      } else {
        _currentIndex = _currentIndex.clamp(0, _playlist.length - 1);
        play(_playlist[_currentIndex]);
      }
    }
    _savePlaylist();
    notifyListeners();
  }

  @override
  void dispose() {
    _lyricTimer?.cancel();
    _positionSaveTimer?.cancel();
    _positionSub?.cancel();
    if (_player.playing && _player.position.inMilliseconds > 0) {
      _storage.savePosition(_player.position.inMilliseconds);
    }
    _player.dispose();
    super.dispose();
  }
}

/// audio_service Handler — 支持 Android Auto / CarWith 浏览
class _MusicAudioHandler extends BaseAudioHandler with SeekHandler, QueueHandler {
  final PlayerService playerService;
  final AudioPlayer player;
  bool _isPlaying = false;

  _MusicAudioHandler({required this.playerService, required this.player}) {
    playbackState.add(_buildState(
      controls: [MediaControl.skipToPrevious, MediaControl.play, MediaControl.skipToNext],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
    ));

    player.playingStream.listen((playing) {
      _isPlaying = playing;
      playbackState.add(_buildState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        playing: playing,
      ));
    });

    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        playbackState.add(_buildState(
          controls: [MediaControl.skipToPrevious, MediaControl.play, MediaControl.skipToNext],
          processingState: AudioProcessingState.completed,
        ));
      }
    });

    // 持续同步位置到系统媒体组件，每秒更新一次
    player.positionStream.listen((position) {
      playbackState.add(_buildState(
        controls: [
          MediaControl.skipToPrevious,
          _isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        playing: _isPlaying,
      ));
    });
  }

  /// 同步播放列表到 audio_service queue（供 Android Auto / CarWith 浏览）
  void syncQueue(List<Song> playlist) {
    final items = playlist.map((s) => MediaItem(
      id: '${s.id}_${s.sourceId}',
      title: s.name,
      artist: s.artist,
      album: s.album,
      duration: s.duration,
      artUri: (s.coverUrl != null && s.coverUrl!.startsWith('http'))
          ? Uri.parse(s.coverUrl!)
          : null,
    )).toList();
    queue.add(items);
  }

  PlaybackState _buildState({
    List<MediaControl> controls = const [],
    Set<MediaAction> systemActions = const {},
    List<int> androidCompactActionIndices = const [],
    bool playing = false,
    AudioProcessingState processingState = AudioProcessingState.ready,
  }) {
    return PlaybackState(
      controls: controls,
      systemActions: systemActions,
      androidCompactActionIndices: androidCompactActionIndices,
      processingState: processingState,
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
    );
  }

  @override
  Future<void> play() async => player.play();
  @override
  Future<void> pause() async => player.pause();
  @override
  Future<void> stop() async { await player.stop(); await super.stop(); }
  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
    playbackState.add(_buildState(
      controls: [
        MediaControl.skipToPrevious,
        _isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      playing: _isPlaying,
    ));
  }
  @override
  Future<void> skipToNext() async => playerService.next();
  @override
  Future<void> skipToPrevious() async => playerService.previous();
  @override
  Future<void> onTaskRemoved() async => await stop();
}
