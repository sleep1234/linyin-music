import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config.dart';
import '../services/player_service.dart';
import '../services/music_source_service.dart';
import '../services/storage_service.dart';
import '../models/models.dart';
import '../utils/lrc_parser.dart';
import 'play_queue_sheet.dart';
import 'search_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  bool _showFullLyric = false;
  final ScrollController _lyricScrollController = ScrollController();
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _lyricScrollController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) {
          return const Scaffold(body: Center(child: Text('没有播放中的歌曲')));
        }

        if (player.player.playing) {
          if (!_rotationController.isAnimating) {
            _rotationController.repeat();
          }
        } else {
          _rotationController.stop();
        }

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  Theme.of(context).colorScheme.surface,
                ],
              ),
            ),
            child: SafeArea(
              child: _showFullLyric
                  ? _buildFullLyricView(player, song)
                  : Column(
                      children: [
                        _buildTopBar(song, player),
                        _buildCover(song),
                        _buildLyricPreview(player),
                        _buildSongInfo(song, player),
                        _buildProgressBar(player),
                        _buildControls(player),
                        _buildBottomBar(player, song),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(Song song, PlayerService player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('正在播放', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 2),
                  Text(song.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Positioned(
              left: 0,
              child: IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => Navigator.pop(context)),
            ),
            if (song.isVip && player.isVipMode)
              Positioned(
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text('VIP', style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(Song song) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: RotationTransition(
          turns: _rotationController,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: ClipOval(
              child: song.coverUrl != null && song.coverUrl!.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: song.coverUrl!,
                      fit: BoxFit.cover,
                      httpHeaders: const {
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                        'Referer': 'https://music.163.com',
                      },
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => Container(color: Colors.grey.shade300, child: const Icon(Icons.music_note, size: 80, color: Colors.white)),
                    )
                  : Container(color: Colors.grey.shade300, child: const Icon(Icons.music_note, size: 80, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  /// 歌词预览 — 专辑下方显示当前歌词上下几句
  Widget _buildLyricPreview(PlayerService player) {
    final lines = player.lrcLines;
    if (lines.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('暂无歌词', style: TextStyle(color: Colors.white54, fontSize: 14))),
      );
    }

    final currentIdx = player.currentLrcIndex;
    final start = (currentIdx - 2).clamp(0, lines.length - 1);
    final end = (currentIdx + 3).clamp(0, lines.length);
    final visibleLines = lines.sublist(start, end);

    return GestureDetector(
      onTap: () => setState(() => _showFullLyric = true),
      child: Container(
        height: 120,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: visibleLines.map((line) {
            final idx = lines.indexOf(line);
            final isCurrent = idx == currentIdx;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                line.text,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.white54,
                  fontSize: isCurrent ? 16 : 13,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 全屏歌词视图
  Widget _buildFullLyricView(PlayerService player, Song song) {
    final lines = player.lrcLines;

    return Column(
      children: [
        _buildTopBar(song, player),
        Expanded(
          child: lines.isEmpty
              ? GestureDetector(
                  onTap: () => setState(() => _showFullLyric = false),
                  child: const Center(child: Text('暂无歌词', style: TextStyle(color: Colors.white70))),
                )
              : _buildScrollableLyric(player, lines),
        ),
        _buildSongInfo(song, player),
        _buildProgressBar(player),
        _buildControls(player),
        _buildBottomBar(player, song),
      ],
    );
  }

  Widget _buildScrollableLyric(PlayerService player, List<LrcLine> lines) {
    final currentIdx = player.currentLrcIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentIdx >= 0 && _lyricScrollController.hasClients) {
        final targetOffset = (currentIdx * 48.0) - 200;
        _lyricScrollController.animateTo(
          targetOffset.clamp(0.0, _lyricScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return GestureDetector(
      onTap: () => setState(() => _showFullLyric = false),
      child: ListView.builder(
        controller: _lyricScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 200),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final isCurrent = index == currentIdx;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GestureDetector(
              onHorizontalDragEnd: (_) {
                player.seek(lines[index].timestamp);
              },
              child: Text(
                lines[index].text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.white54,
                  fontSize: isCurrent ? 20 : 16,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  height: 1.6,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongInfo(Song song, PlayerService player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => SearchScreen(initialQuery: song.artist),
                    ));
                  },
                  child: Text(
                    '${song.artist}${song.album.isNotEmpty ? ' · ${song.album}' : ''}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (song.isVip)
            IconButton(
              icon: Icon(player.isVipMode ? Icons.lock_open : Icons.lock, color: player.isVipMode ? const Color(0xFFEC4141) : Colors.grey),
              onPressed: player.toggleVipMode,
              tooltip: player.isVipMode ? '本地VIP已开启' : '点击开启本地VIP',
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(PlayerService player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StreamBuilder<Duration>(
        stream: player.positionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          return StreamBuilder<Duration?>(
            stream: player.durationStream,
            builder: (context, snapshot) {
              final duration = snapshot.data ?? Duration.zero;
              return Column(
                children: [
                  Slider(
                    value: duration.inMilliseconds > 0
                        ? position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble())
                        : 0,
                    max: duration.inMilliseconds.toDouble(),
                    onChanged: (value) => player.seek(Duration(milliseconds: value.toInt())),
                    activeColor: const Color(0xFFEC4141),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position), style: const TextStyle(fontSize: 12)),
                        Text(_formatDuration(duration), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildControls(PlayerService player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(icon: Icon(_getPlayModeIcon(player.playMode)), onPressed: player.togglePlayMode),
          IconButton(icon: const Icon(Icons.skip_previous, size: 36), onPressed: player.previous),
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(color: Color(0xFFEC4141), shape: BoxShape.circle),
            child: player.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : IconButton(
                    icon: Icon(player.player.playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36),
                    onPressed: player.togglePlay,
                  ),
          ),
          IconButton(icon: const Icon(Icons.skip_next, size: 36), onPressed: player.next),
          IconButton(icon: const Icon(Icons.queue_music), onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const PlayQueueSheet(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomBar(PlayerService player, Song song) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          PopupMenuButton<AudioQuality>(
            onSelected: player.setQuality,
            itemBuilder: (context) => AudioQuality.values.map((q) {
              return PopupMenuItem(
                value: q,
                child: Row(children: [
                  if (q == player.quality) const Icon(Icons.check, size: 16, color: Color(0xFFEC4141)),
                  const SizedBox(width: 8),
                  Text(q.label),
                ]),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
              child: Text('音质: ${player.quality.shortLabel}', style: const TextStyle(fontSize: 12)),
            ),
          ),
          IconButton(
            icon: Icon(_showFullLyric ? Icons.album : Icons.lyrics, color: _showFullLyric ? const Color(0xFFEC4141) : null),
            onPressed: () {
              setState(() => _showFullLyric = !_showFullLyric);
            },
            tooltip: '歌词',
          ),
          IconButton(
            icon: Icon(
              player.isFavorite(song) ? Icons.favorite : Icons.favorite_border,
              color: player.isFavorite(song) ? const Color(0xFFEC4141) : null,
            ),
            onPressed: () => player.toggleFavorite(song),
            tooltip: player.isFavorite(song) ? '取消收藏' : '收藏',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadSong(context, song),
            tooltip: '下载',
          ),
        ],
      ),
    );
  }

  IconData _getPlayModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequential: return Icons.repeat;
      case PlayMode.loop: return Icons.repeat;
      case PlayMode.singleLoop: return Icons.repeat_one;
      case PlayMode.shuffle: return Icons.shuffle;
    }
  }

  String _formatDuration(Duration duration) {
    final min = duration.inMinutes;
    final sec = duration.inSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadSong(BuildContext context, Song song) async {
    final sourceService = context.read<MusicSourceService>();
    final storage = context.read<StorageService>();

    final downloaded = await storage.isDownloaded(song.id, song.sourceId);
    if (downloaded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${song.name} 已经下载过了')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在下载 ${song.name}...')),
      );
    }

    final url = await sourceService.getSongUrl(song);
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取下载链接失败')),
        );
      }
      return;
    }

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final downloadDir = await storage.getDownloadDir();
        final fileName = '${song.artist} - ${song.name}.mp3'
            .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        final filePath = '$downloadDir/$fileName';
        await File(filePath).writeAsBytes(res.bodyBytes);

        final downloadedSong = Song(
          id: song.id, name: song.name, artist: song.artist,
          artistId: song.artistId, album: song.album, albumId: song.albumId,
          coverUrl: song.coverUrl, urlId: song.urlId, duration: song.duration,
          sourceId: song.sourceId, isVip: song.isVip, filePath: filePath,
        );
        await storage.addDownload(downloadedSong, filePath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${song.name} 下载完成')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }
}
