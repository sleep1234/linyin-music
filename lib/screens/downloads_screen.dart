import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../models/models.dart';

/// 本地下载页面
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Map<String, dynamic>> _downloads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    final storage = context.read<StorageService>();
    final downloads = await storage.getDownloads();
    if (mounted) {
      setState(() {
        _downloads = downloads;
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
      appBar: AppBar(title: const Text('本地下载')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _downloads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('还没有下载的歌曲', style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      Text('播放歌曲时点击下载按钮即可保存', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _downloads.length,
                  itemBuilder: (context, index) => _buildDownloadItem(_downloads[index], index),
                ),
    );
  }

  Widget _buildDownloadItem(Map<String, dynamic> item, int index) {
    final player = context.read<PlayerService>();
    Song song;
    try {
      final json = jsonDecode(item['song_json'] as String) as Map<String, dynamic>;
      song = Song.fromJson(json);
    } catch (_) {
      song = Song(
        id: item['id'] as String,
        name: item['name'] as String,
        artist: item['artist'] as String,
        album: item['album'] as String,
        coverUrl: item['cover_url'] as String?,
        sourceId: item['source_id'] as String,
        isVip: (item['is_vip'] as int) == 1,
      );
    }
    final filePath = item['file_path'] as String;

    return ListTile(
      leading: Container(
        width: 44, height: 44,
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
                  errorWidget: (_, __, ___) => const Icon(Icons.download_done, color: Color(0xFFEC4141)),
                ),
              )
            : const Icon(Icons.download_done, color: Color(0xFFEC4141)),
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
          const Icon(Icons.offline_pin, size: 12, color: Colors.green),
          const SizedBox(width: 4),
          Text('已下载', style: TextStyle(color: Colors.green.shade700, fontSize: 10)),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: () async {
          final storage = context.read<StorageService>();
          await storage.removeDownload(song.id, song.sourceId);
          setState(() => _downloads.removeAt(index));
        },
      ),
      onTap: () async {
        // 播放本地文件
        final file = File(filePath);
        if (await file.exists()) {
          final localSong = Song(
            id: song.id, name: song.name, artist: song.artist,
            artistId: song.artistId, album: song.album, albumId: song.albumId,
            coverUrl: song.coverUrl, urlId: song.urlId, duration: song.duration,
            sourceId: song.sourceId, isVip: song.isVip, filePath: filePath,
          );
          await player.play(localSong);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('本地文件已丢失，尝试在线播放')),
            );
          }
          player.play(song);
        }
      },
    );
  }
}
