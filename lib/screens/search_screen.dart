import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_source_service.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../models/models.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Song> _results = [];
  bool _isLoading = false;
  List<String> _searchHistory = [];
  bool _hasSearched = false; // 是否已执行过搜索

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    // 如果有初始搜索词，自动搜索
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search(keyword: widget.initialQuery);
      });
    }
  }

  Future<void> _loadSearchHistory() async {
    final storage = context.read<StorageService>();
    final history = await storage.getSearchHistory();
    if (mounted) {
      setState(() => _searchHistory = history);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search({String? keyword}) async {
    final kw = keyword ?? _controller.text.trim();
    if (kw.isEmpty) return;
    _controller.text = kw;

    // 保存搜索历史
    final storage = context.read<StorageService>();
    storage.addSearchHistory(kw);

    setState(() {
      _isLoading = true;
      _results = [];
      _hasSearched = true;
    });

    final sourceService = context.read<MusicSourceService>();
    final results = await sourceService.search(kw);

    if (mounted) {
      setState(() {
        _results = List.from(results);
        _isLoading = false;
      });
    }

    // 加载封面
    bool anyUpdated = false;
    for (final song in results) {
      if (song.coverUrl != null && !song.coverUrl!.startsWith('http')) {
        final url = await sourceService.getCover(song.coverUrl!, song.sourceId);
        if (url != null) {
          song.coverUrl = url;
          anyUpdated = true;
        }
      }
    }
    if (anyUpdated && mounted) {
      setState(() => _results = List.from(_results));
    }

    // 刷新搜索历史
    _loadSearchHistory();
  }

  String _getSourceLabel(String sourceId) {
    switch (sourceId) {
      case 'netease': return '网易云';
      case 'kuwo': return '酷我';
      case 'tencent': return 'QQ音乐';
      case 'bilibili': return 'B站';
      case 'joox': return 'JOOX';
      case 'tencent': return 'QQ';
      case 'kugou': return '酷狗';
      case 'migu': return '咪咕';
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
      case 'tencent': return const Color(0xFF10B981);
      case 'kugou': return const Color(0xFFF59E0B);
      case 'migu': return const Color(0xFF8B5CF6);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索歌曲、歌手、专辑',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          TextButton(
            onPressed: () => _search(),
            child: const Text('搜索'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索状态
          if (_isLoading)
            const LinearProgressIndicator(),
          // 搜索结果数量
          if (_results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '共 ${_results.length} 首',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '来自多音源',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
          // 内容区域
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasSearched
                    ? _results.isEmpty
                        ? const Center(child: Text('未找到相关歌曲'))
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final song = _results[index];
                              return _buildSongItem(song, index);
                            },
                          )
                    : _buildSearchHistory(), // 未搜索时显示搜索历史
          ),
        ],
      ),
    );
  }

  /// 搜索历史 + 热门搜索
  Widget _buildSearchHistory() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_searchHistory.isNotEmpty) ...[
          Row(
            children: [
              const Text('搜索历史', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () async {
                  final storage = context.read<StorageService>();
                  await storage.clearSearchHistory();
                  setState(() => _searchHistory = []);
                },
                tooltip: '清空历史',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _searchHistory.map((kw) {
              return ActionChip(
                label: Text(kw),
                onPressed: () => _search(keyword: kw),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
        // 热门搜索词
        const Text('热门搜索', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            '周杰伦', '薛之谦', '林俊杰', '邓紫棋', '陈奕迅',
            '毛不易', '李荣浩', '华晨宇', '张学友', 'Taylor Swift',
          ].map((kw) {
            return ActionChip(
              label: Text(kw),
              onPressed: () => _search(keyword: kw),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSongItem(Song song, int index) {
    final player = context.read<PlayerService>();

    return ListTile(
      key: ValueKey('${song.id}_${song.sourceId}_${song.coverUrl ?? ''}'),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade200,
        ),
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
                  placeholder: (context, url) => const Center(
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.music_note),
                ),
              )
            : const Icon(Icons.music_note),
      ),
      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          // 音源标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: _getSourceColor(song.sourceId).withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _getSourceLabel(song.sourceId),
              style: TextStyle(color: _getSourceColor(song.sourceId), fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ),
          if (song.isVip)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('VIP', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 10)),
            ),
          Expanded(
            child: Text(
              '${song.artist}${song.album.isNotEmpty ? ' · ${song.album}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
      trailing: Text(
        song.durationText,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      ),
      onTap: () {
        if (player.currentSong?.id == song.id && player.currentSong?.sourceId == song.sourceId) {
          Navigator.pop(context);
        } else {
          player.play(song, playlist: _results, index: index);
          Navigator.pop(context);
        }
      },
    );
  }
}
