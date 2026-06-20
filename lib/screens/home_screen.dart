import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../services/music_source_service.dart';
import '../models/models.dart';
import 'search_screen.dart';
import 'player_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'playlist_tab.dart';
import 'downloads_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<Song> _rankSongs = [];
  bool _loadingRank = false;
  int _currentRankId = 3778678; // 默认热歌榜

  static const List<Map<String, dynamic>> _rankList = [
    {'id': 3778678, 'name': '热歌榜'},
    {'id': 3779629, 'name': '新歌榜'},
    {'id': 19723756, 'name': '飙升榜'},
    {'id': 71385702, 'name': 'ACG榜'},
    {'id': 2809513713, 'name': '欧美榜'},
    {'id': 5059644681, 'name': '日语榜'},
    {'id': 71384707, 'name': '古典榜'},
    {'id': 1978921795, 'name': '电音榜'},
    {'id': 745956260, 'name': '韩语榜'},
  ];

  @override
  void initState() {
    super.initState();
    _loadRank();
  }

  Future<void> _loadRank() async {
    setState(() => _loadingRank = true);
    final sourceService = context.read<MusicSourceService>();
    final songs = await sourceService.getNeteaseRank(id: _currentRankId);
    if (mounted) {
      setState(() {
        _rankSongs = songs;
        _loadingRank = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDiscoverPage(),
          _buildPlaylistPage(),
          _buildMyPage(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniPlayer(),
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore),
                selectedIcon: Icon(Icons.explore, color: Color(0xFFEC4141)),
                label: '发现',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music),
                selectedIcon: Icon(Icons.library_music, color: Color(0xFFEC4141)),
                label: '歌单',
              ),
              NavigationDestination(
                icon: Icon(Icons.person),
                selectedIcon: Icon(Icons.person, color: Color(0xFFEC4141)),
                label: '我的',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return Consumer<PlayerService>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
          },
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                // 封面
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey.shade300),
                  child: song.coverUrl != null
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      Text(song.artist, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: player.isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(player.player.playing ? Icons.pause : Icons.play_arrow),
                  onPressed: player.isLoading ? null : player.togglePlay,
                ),
                IconButton(icon: const Icon(Icons.skip_next), onPressed: player.next),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscoverPage() {
    return SafeArea(
      child: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
              },
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('搜索歌曲、歌手、专辑', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
          // 排行榜标签（可横向滚动）
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _rankList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final rank = _rankList[index];
                final isSelected = rank['id'] == _currentRankId;
                return ChoiceChip(
                  label: Text(rank['name'] as String),
                  selected: isSelected,
                  onSelected: (_) {
                    if (!isSelected) {
                      setState(() => _currentRankId = rank['id'] as int);
                      _loadRank();
                    }
                  },
                  selectedColor: const Color(0xFFEC4141).withOpacity(0.15),
                );
              },
            ),
          ),
          // 排行榜歌曲
          Expanded(
            child: _loadingRank
                ? const Center(child: CircularProgressIndicator())
                : _rankSongs.isEmpty
                    ? Center(child: Text('加载失败', style: TextStyle(color: Colors.grey.shade500)))
                    : RefreshIndicator(
                        onRefresh: _loadRank,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _rankSongs.length,
                          itemBuilder: (context, index) {
                            final song = _rankSongs[index];
                            return _buildRankSongItem(song, index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankSongItem(Song song, int index) {
    final player = context.read<PlayerService>();
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: index < 3 ? const Color(0xFFEC4141) : Colors.grey,
                fontSize: index < 3 ? 18 : 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Colors.grey.shade200),
            child: song.coverUrl != null && song.coverUrl!.startsWith('http')
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: song.coverUrl!,
                      fit: BoxFit.cover,
                      httpHeaders: const {
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                        'Referer': 'https://music.163.com',
                      },
                      errorWidget: (_, __, ___) => const Icon(Icons.music_note, size: 20),
                    ),
                  )
                : const Icon(Icons.music_note, size: 20),
          ),
        ],
      ),
      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(song.durationText, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              player.isFavorite(song) ? Icons.favorite : Icons.favorite_border,
              color: player.isFavorite(song) ? const Color(0xFFEC4141) : null,
              size: 20,
            ),
            onPressed: () => player.toggleFavorite(song),
          ),
        ],
      ),
      onTap: () {
        if (player.currentSong?.id == song.id && player.currentSong?.sourceId == song.sourceId) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerScreen()));
        } else {
          player.play(song, playlist: _rankSongs, index: index);
        }
      },
    );
  }

  Widget _buildPlaylistPage() {
    return const PlaylistTab();
  }

  Widget _buildMyPage() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 用户信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 30, child: Icon(Icons.person, size: 30)),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('本地VIP用户', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('所有歌曲免费畅听', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildMenuItem(Icons.download, '本地下载', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()));
          }),
          _buildMenuItem(Icons.history, '播放历史', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
          }),
          _buildMenuItem(Icons.favorite, '我喜欢的', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
          }),
          _buildMenuItem(Icons.settings, '设置', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
