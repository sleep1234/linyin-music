import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../services/music_source_service.dart';
import '../services/storage_service.dart';
import '../models/models.dart';
import 'player_screen.dart';
/// 歌单Tab
class PlaylistTab extends StatefulWidget {
  const PlaylistTab({super.key});

  @override
  State<PlaylistTab> createState() => _PlaylistTabState();
}

class _PlaylistTabState extends State<PlaylistTab> {
  List<Map<String, dynamic>> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final storage = context.read<StorageService>();
    final playlists = await storage.getPlaylists();
    if (mounted) {
      setState(() {
        _playlists = playlists;
        _loading = false;
      });
    }
  }

  Future<void> _createPlaylist() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('新建歌单'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '歌单名称'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      final storage = context.read<StorageService>();
      await storage.createPlaylist(name);
      _loadPlaylists();
    }
  }

  /// 导入网易云用户所有歌单
  Future<void> _importNeteasePlaylist() async {
    final uid = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('导入网易云歌单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '输入网易云用户UID',
                  helperText: '将导入该用户所有歌单',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('导入'),
            ),
          ],
        );
      },
    );

    if (uid == null || uid.isEmpty) return;

    // 显示加载中
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在获取歌单列表...'), duration: Duration(minutes: 1)),
    );

    // 获取用户所有歌单
    final sourceService = context.read<MusicSourceService>();
    final playlists = await sourceService.getUserPlaylists(uid);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (playlists.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到歌单，请检查UID是否正确')),
        );
      }
      return;
    }

    // 逐个导入
    final storage = context.read<StorageService>();
    int totalSongs = 0;
    int successCount = 0;

    for (final pl in playlists) {
      final playlistId = pl['id'] as String;
      final playlistName = pl['name'] as String;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在导入「$playlistName」...'), duration: const Duration(seconds: 3)),
      );

      try {
        final songs = await sourceService.getNeteaseRank(id: int.parse(playlistId), count: 100);
        if (songs.isNotEmpty) {
          final localId = await storage.createPlaylist(playlistName);
          for (final song in songs) {
            await storage.addSongToPlaylist(localId, song);
          }
          totalSongs += songs.length;
          successCount++;
        }
      } catch (e) {
        debugPrint('[导入] $playlistName 失败: $e');
      }
    }

    _loadPlaylists();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入完成：$successCount 个歌单，共 $totalSongs 首歌曲')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('我的歌单', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.cloud_download),
                  onPressed: _importNeteasePlaylist,
                  tooltip: '导入网易云歌单',
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _createPlaylist,
                  tooltip: '新建歌单',
                ),
              ],
            ),
          ),
          // 歌单列表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _playlists.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.library_music, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('还没有歌单', style: TextStyle(color: Colors.grey.shade500)),
                            const SizedBox(height: 8),
                            Text('点击右上角 + 创建歌单', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _playlists.length,
                        itemBuilder: (context, index) {
                          final pl = _playlists[index];
                          return _buildPlaylistItem(pl);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistItem(Map<String, dynamic> pl) {
    final id = pl['id'] as String;
    final name = pl['name'] as String;

    return ListTile(
      leading: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFEC4141).withOpacity(0.1),
        ),
        child: const Icon(Icons.library_music, color: Color(0xFFEC4141)),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: FutureBuilder<int>(
        future: context.read<StorageService>().getPlaylistSongCount(id),
        builder: (ctx, snap) {
          final count = snap.data ?? 0;
          return Text('$count 首歌曲');
        },
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          final storage = context.read<StorageService>();
          if (action == 'rename') {
            final newName = await showDialog<String>(
              context: context,
              builder: (ctx) {
                final controller = TextEditingController(text: name);
                return AlertDialog(
                  title: const Text('重命名歌单'),
                  content: TextField(controller: controller, autofocus: true),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                      child: const Text('确定'),
                    ),
                  ],
                );
              },
            );
            if (newName != null && newName.isNotEmpty) {
              await storage.renamePlaylist(id, newName);
              _loadPlaylists();
            }
          } else if (action == 'delete') {
            await storage.deletePlaylist(id);
            _loadPlaylists();
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'rename', child: Text('重命名')),
          const PopupMenuItem(value: 'delete', child: Text('删除歌单')),
        ],
      ),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(playlistId: id, playlistName: name),
        )).then((_) => _loadPlaylists()); // 返回时刷新
      },
    );
  }
}

/// 歌单详情页
class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final String playlistName;

  const PlaylistDetailScreen({super.key, required this.playlistId, required this.playlistName});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final storage = context.read<StorageService>();
    final songs = await storage.getPlaylistSongs(widget.playlistId);
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
        title: Text(widget.playlistName),
        actions: [
          if (_songs.isNotEmpty)
            TextButton.icon(
              onPressed: _playAll,
              icon: const Icon(Icons.play_arrow),
              label: const Text('播放全部'),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addSongFromSearch,
            tooltip: '添加歌曲',
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
                      Icon(Icons.music_note, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('歌单是空的', style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      Text('点击右上角 + 添加歌曲', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
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
        icon: const Icon(Icons.close, size: 18),
        onPressed: () async {
          final storage = context.read<StorageService>();
          await storage.removeSongFromPlaylist(widget.playlistId, song.id, song.sourceId);
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
    );
  }

  void _playAll() {
    final player = context.read<PlayerService>();
    if (_songs.isNotEmpty) {
      player.play(_songs.first, playlist: _songs, index: 0);
    }
  }

  /// 从搜索页选歌加入歌单
  Future<void> _addSongFromSearch() async {
    // 打开搜索页，选歌后返回
    final result = await Navigator.push<Song>(
      context,
      MaterialPageRoute(
        builder: (_) => _SongPickerScreen(),
      ),
    );
    if (result != null) {
      final storage = context.read<StorageService>();
      await storage.addSongToPlaylist(widget.playlistId, result);
      _loadSongs();
    }
  }
}

/// 选歌页面 — 复用搜索功能
class _SongPickerScreen extends StatefulWidget {
  @override
  State<_SongPickerScreen> createState() => _SongPickerScreenState();
}

class _SongPickerScreenState extends State<_SongPickerScreen> {
  final _controller = TextEditingController();
  List<Song> _results = [];
  bool _isLoading = false;

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    setState(() { _isLoading = true; _results = []; });

    final sourceService = context.read<MusicSourceService>();
    final results = await sourceService.search(keyword);

    // 加载封面
    for (final song in results) {
      if (song.coverUrl != null && !song.coverUrl!.startsWith('http')) {
        final url = await sourceService.getCover(song.coverUrl!, song.sourceId);
        if (url != null) song.coverUrl = url;
      }
    }

    if (mounted) {
      setState(() { _results = results; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择歌曲'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '搜索歌曲',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: _search),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (ctx, i) {
                      final song = _results[i];
                      return ListTile(
                        title: Text(song.name),
                        subtitle: Text(song.artist, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        trailing: const Icon(Icons.add),
                        onTap: () => Navigator.pop(ctx, song),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
