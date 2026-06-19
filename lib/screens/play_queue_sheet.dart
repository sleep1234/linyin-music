import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../models/models.dart';

/// 播放队列 — Bottom Sheet
class PlayQueueSheet extends StatelessWidget {
  const PlayQueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, player, _) {
        final playlist = player.playlist;
        final currentIndex = player.currentIndex;

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  // 拖动手柄
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // 标题栏
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text('播放队列 (${playlist.length})',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            player.clearPlaylist();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('清空'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // 歌曲列表
                  Expanded(
                    child: playlist.isEmpty
                        ? const Center(child: Text('队列为空'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: playlist.length,
                            itemBuilder: (context, index) {
                              final song = playlist[index];
                              final isCurrent = index == currentIndex;
                              return _buildQueueItem(context, player, song, index, isCurrent);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQueueItem(BuildContext context, PlayerService player, Song song, int index, bool isCurrent) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Colors.grey.shade200),
        child: isCurrent
            ? const Icon(Icons.play_arrow, color: Color(0xFFEC4141), size: 20)
            : song.coverUrl != null && song.coverUrl!.startsWith('http')
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: song.coverUrl!,
                      fit: BoxFit.cover,
                      httpHeaders: const {
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                        'Referer': 'https://music.163.com',
                      },
                      errorWidget: (_, __, ___) => const Icon(Icons.music_note, size: 16),
                    ),
                  )
                : const Icon(Icons.music_note, size: 16),
      ),
      title: Text(
        song.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? const Color(0xFFEC4141) : null,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? const Color(0xFFEC4141).withOpacity(0.7) : Colors.grey.shade600,
          fontSize: 12,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        onPressed: () => player.removeSong(index),
      ),
      onTap: () {
        player.play(song, playlist: player.playlist, index: index);
      },
    );
  }
}
