import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../models/models.dart';
import 'player_screen.dart';

/// 播放历史
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final storage = context.read<StorageService>();
    final songs = await storage.getHistory();
    if (mounted) {
      setState(() {
        _songs = songs;
        _loading = false;
      });
    }
  }

  String _getSourceLabel(String sourceId) {
    switch (sourceId) {
      case 'netease': return '网易云';
      case 'kuwo': return '酷我';
      case 'tencent': return 'QQ音乐';
      case 'bilibili': return 'B站';
      case 'joox': return 'JOOX';
      default: return sourceId;
    }
  }

  Color _getSourceColor(String sourceId) {
    switch (sourceId) {
      case 'netease': return const Color(0xFFEC4141);
      case 'kuwo': return const Color(0xFF3B82F6);
      case 'tencent': return const Color(0xFF1DB954);
      case 'bilibili': return const Color(0xFFFB7299);
      case 'joox': return const Color(0xFF2196F3);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放历史'),
        actions: [
          if (_songs.isNotEmpty)
            TextButton.icon(
              onPressed: _playAll,
              icon: const Icon(Icons.play_arrow),
              label: const Text('播放全部'),
            ),
          if (_songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '清空历史',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('还没有播放记录', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    itemCount: _songs.length,
                    itemBuilder: (context, index) => _buildSongItem(_songs[index], index),
                  ),
                ),
    );
  }

  Widget _buildSongItem(Song song, int index) {
    final player = context.read<PlayerService>();

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey.shade200),
        child: song.coverUrl != null && song.coverUrl!.startsWith('http')
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: song.coverUrl!,
                  fit: BoxFit.cover,
                  httpHeaders: const {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                    'Referer': 'https://music.163.com',
                  },
                  errorWidget: (_, __, ___) => const Icon(Icons.music_note),
                ),
              )
            : const Icon(Icons.music_note),
      ),
      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: _getSourceColor(song.sourceId).withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(_getSourceLabel(song.sourceId),
                style: TextStyle(color: _getSourceColor(song.sourceId), fontSize: 10)),
          ),
          Expanded(
            child: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
        ],
      ),
      trailing: Text(song.durationText, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      onTap: () {
        if (player.currentSong?.id == song.id && player.currentSong?.sourceId == song.sourceId) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
        } else {
          player.play(song, playlist: _songs, index: index);
        }
      },
    );
  }

  void _playAll() {
    final player = context.read<PlayerService>();
    if (_songs.isNotEmpty) {
      player.play(_songs.first, playlist: _songs, index: 0);
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空播放历史'),
        content: const Text('确定要清空所有播放历史吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final storage = context.read<StorageService>();
      await storage.clearHistory();
      setState(() => _songs = []);
    }
  }
}
