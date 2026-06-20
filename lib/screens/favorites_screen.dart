import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../models/models.dart';
import 'player_screen.dart';

/// 我喜欢的 —— 收藏歌曲列表
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final storage = context.read<StorageService>();
    final songs = await storage.getFavorites();
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
      default: return sourceId;
    }
  }

  Color _getSourceColor(String sourceId) {
    switch (sourceId) {
      case 'netease': return const Color(0xFFEC4141);
      case 'kuwo': return const Color(0xFF3B82F6);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我喜欢的'),
        actions: [
          if (_songs.isNotEmpty)
            TextButton.icon(
              onPressed: _playAll,
              icon: const Icon(Icons.play_arrow),
              label: const Text('播放全部'),
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
                      Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('还没有收藏的歌曲', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _songs.length,
                  itemBuilder: (context, index) => _buildSongItem(_songs[index], index),
                ),
    );
  }

  Widget _buildSongItem(Song song, int index) {
    final player = context.read<PlayerService>();

    return Dismissible(
      key: ValueKey('${song.id}_${song.sourceId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        // 如果 PlayerService 里还标记为收藏，同步移除
        final player = context.read<PlayerService>();
        if (player.isFavorite(song)) {
          await player.toggleFavorite(song);
        }
        setState(() => _songs.removeAt(index));
      },
      child: ListTile(
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
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: Color(0xFFEC4141)),
          onPressed: () async {
            final player = context.read<PlayerService>();
            await player.toggleFavorite(song);
            setState(() => _songs.removeAt(index));
          },
        ),
        onTap: () {
          if (player.currentSong?.id == song.id && player.currentSong?.sourceId == song.sourceId) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
          } else {
            player.play(song, playlist: _songs, index: index);
          }
        },
      ),
    );
  }

  void _playAll() {
    final player = context.read<PlayerService>();
    if (_songs.isNotEmpty) {
      player.play(_songs.first, playlist: _songs, index: 0);
    }
  }
}
