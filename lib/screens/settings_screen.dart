import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../config.dart';

/// 设置页面
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerService>();
    final storage = context.read<StorageService>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 播放设置
          _sectionHeader('播放设置'),
          SwitchListTile(
            title: const Text('本地VIP模式'),
            subtitle: const Text('解锁所有VIP歌曲免费播放'),
            value: player.isVipMode,
            onChanged: (_) => player.toggleVipMode(),
          ),
          ListTile(
            title: const Text('默认音质'),
            subtitle: Text(player.quality.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showQualityPicker(context, player),
          ),

          const Divider(),

          // 音源设置
          _sectionHeader('音源设置'),
          // 网易云
          SwitchListTile(
            title: const Text('网易云音乐'),
            subtitle: const Text('搜索与播放时使用网易云音源'),
            value: true, // 暂时不可关闭
            onChanged: null,
          ),
          SwitchListTile(
            title: const Text('酷我音乐'),
            subtitle: const Text('搜索与播放时使用酷我音源'),
            value: true,
            onChanged: null,
          ),

          const Divider(),

          // 缓存管理
          _sectionHeader('缓存管理'),
          ListTile(
            title: const Text('清理播放链接缓存'),
            subtitle: const Text('清理超过1小时的播放链接缓存'),
            trailing: const Icon(Icons.delete_outline),
            onTap: () async {
              await storage.cleanExpiredCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缓存已清理')),
                );
              }
            },
          ),
          ListTile(
            title: const Text('清空播放历史'),
            subtitle: const Text('删除所有播放历史记录'),
            trailing: const Icon(Icons.delete_outline),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('确认清空'),
                  content: const Text('确定要清空所有播放历史吗？'),
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
                await storage.clearHistory();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('播放历史已清空')),
                  );
                }
              }
            },
          ),
          ListTile(
            title: const Text('清空搜索历史'),
            subtitle: const Text('删除所有搜索历史记录'),
            trailing: const Icon(Icons.delete_outline),
            onTap: () async {
              await storage.clearSearchHistory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('搜索历史已清空')),
                );
              }
            },
          ),

          const Divider(),

          // 关于
          _sectionHeader('关于'),
          const ListTile(
            title: Text('版本'),
            subtitle: Text('1.0.0'),
          ),
          const ListTile(
            title: Text('说明'),
            subtitle: Text('本应用仅供学习交流使用，所有音源来自第三方API'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  void _showQualityPicker(BuildContext context, PlayerService player) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AudioQuality.values.map((q) {
            return ListTile(
              title: Text(q.label),
              trailing: q == player.quality ? const Icon(Icons.check, color: Color(0xFFEC4141)) : null,
              onTap: () {
                player.setQuality(q);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
