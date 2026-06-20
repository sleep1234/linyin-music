import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_source_service.dart';
import '../services/storage_service.dart';
import '../services/player_service.dart';
import '../models/models.dart';

/// 歌单导入页面
class ImportPlaylistScreen extends StatefulWidget {
  const ImportPlaylistScreen({super.key});

  @override
  State<ImportPlaylistScreen> createState() => _ImportPlaylistScreenState();
}

class _ImportPlaylistScreenState extends State<ImportPlaylistScreen> {
  final _urlController = TextEditingController();
  bool _isImporting = false;
  int _current = 0;
  int _total = 0;
  String _currentSong = '';
  List<Song> _importedSongs = [];

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _startImport() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入歌单链接')),
      );
      return;
    }

    final parsed = MusicSourceService.parseShareUrl(url);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法识别此链接，请使用网易云或汽水音乐的分享链接')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _current = 0;
      _total = 0;
      _currentSong = '';
      _importedSongs = [];
    });

    final sourceService = context.read<MusicSourceService>();
    final songs = await sourceService.importPlaylist(
      url,
      onProgress: (current, total, songName) {
        if (mounted) {
          setState(() {
            _current = current;
            _total = total;
            _currentSong = songName;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isImporting = false;
        _importedSongs = songs;
      });

      if (songs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功匹配 ${songs.length} 首歌曲')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未匹配到任何歌曲')),
        );
      }
    }
  }

  Future<void> _saveAsPlaylist() async {
    if (_importedSongs.isEmpty) return;

    final nameController = TextEditingController(text: '导入的歌单');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存为歌单'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: '歌单名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final storage = context.read<StorageService>();
    final playlistId = await storage.createPlaylist(name);
    for (final song in _importedSongs) {
      await storage.addSongToPlaylist(playlistId, song);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('歌单「$name」已保存，共 ${_importedSongs.length} 首')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入歌单'),
        actions: [
          if (_importedSongs.isNotEmpty)
            TextButton(
              onPressed: _saveAsPlaylist,
              child: const Text('保存歌单', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 支持的平台提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('支持的平台', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('• 网易云音乐 - 复制歌单分享链接'),
                  Text('• 汽水音乐 - 复制歌单分享链接'),
                  SizedBox(height: 4),
                  Text('导入后会在5个音源中搜索匹配', style: TextStyle(fontSize: 12, color: Colors.white54)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // URL 输入
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: '粘贴歌单分享链接...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // 导入按钮
            ElevatedButton.icon(
              onPressed: _isImporting ? null : _startImport,
              icon: _isImporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              label: Text(_isImporting ? '导入中...' : '开始导入'),
            ),
            const SizedBox(height: 16),

            // 进度
            if (_isImporting) ...[
              LinearProgressIndicator(value: _total > 0 ? _current / _total : null),
              const SizedBox(height: 8),
              Text(
                _total > 0 ? '$_current/$_total  $_currentSong' : '正在获取歌单...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],

            // 结果列表
            if (_importedSongs.isNotEmpty) ...[
              const Divider(),
              Text('匹配结果 (${_importedSongs.length}首)', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _importedSongs.length,
                  itemBuilder: (context, index) {
                    final song = _importedSongs[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: _getSourceColor(song.sourceId),
                        child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                      ),
                      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${song.artist}${song.album.isNotEmpty ? ' · ${song.album}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: Text(
                        _getSourceName(song.sourceId),
                        style: TextStyle(fontSize: 11, color: _getSourceColor(song.sourceId)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

  String _getSourceName(String sourceId) {
    switch (sourceId) {
      case 'netease': return '网易云';
      case 'kuwo': return '酷我';
      case 'tencent': return 'QQ音乐';
      case 'bilibili': return 'B站';
      case 'joox': return 'JOOX';
      default: return sourceId;
    }
  }
}
