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

class _PlayerScreenState extends State<PlayerScreen> {
  bool _showLyric = false;
  final ScrollController _lyricScrollController = ScrollController();

  @override
  void dispose() {
    _lyricScrollController.dispose();
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
              child: Column(
                children: [
                  _buildTopBar(song, player),
                  Expanded(
                    child: _showLyric ? _buildLyricView(player) : _buildCover(song),
                  ),
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
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => Navigator.pop(context)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('正在播放', style: TextStyle(fontSize: 12, color: Colors.white70)),
                Text(song.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (song.isVip && player.isVipMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
              child: const Text('VIP', style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _buildCover(Song song) {
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
    );
  }

  /// 歌词视图 — 自动高亮当前行
  Widget _buildLyricView(PlayerService player) {
    final lines = player.lrcLines;
    if (lines.isEmpty) {
      return const Center(child: Text('暂无歌词', style: TextStyle(color: Colors.white70)));
    }

    final currentIdx = player.currentLrcIndex;

    // 自动滚动到当前行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentIdx >= 0 && _lyricScrollController.hasClients) {
        // 每行大约高度 40，滚动到当前行居中
        final targetOffset = (currentIdx * 48.0) - 200;
        _lyricScrollController.animateTo(
          targetOffset.clamp(0.0, _lyricScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _lyricScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 200),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final isCurrent = index == currentIdx;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: GestureDetector(
            onTap: () {
              // 点击歌词行跳转
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
            icon: Icon(_showLyric ? Icons.album : Icons.lyrics, color: _showLyric ? const Color(0xFFEC4141) : null),
            onPressed: () {
              setState(() => _showLyric = !_showLyric);
            },
            tooltip: '歌词',
          ),
          // 收藏按钮
          IconButton(
            icon: Icon(
              player.isFavorite(song) ? Icons.favorite : Icons.favorite_border,
              color: player.isFavorite(song) ? const Color(0xFFEC4141) : null,
            ),
            onPressed: () => player.toggleFavorite(song),
            tooltip: player.isFavorite(song) ? '取消收藏' : '收藏',
          ),
          // 下载按钮
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

  /// 下载当前歌曲
  Future<void> _downloadSong(BuildContext context, Song song) async {
    final sourceService = context.read<MusicSourceService>();
    final storage = context.read<StorageService>();

    // 检查是否已下载
    final downloaded = await storage.isDownloaded(song.id, song.sourceId);
    if (downloaded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${song.name} 已经下载过了')),
        );
      }
      return;
    }

    // 获取播放链接
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
        await storage.addDownload(song, filePath);

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
