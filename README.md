---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '6d7575fc-e3d8-417b-891b-d4c7cf862f82'
  PropagateID: '6d7575fc-e3d8-417b-891b-d4c7cf862f82'
  ReservedCode1: '20744d9e-b05c-4e20-aced-0b23982daaf9'
  ReservedCode2: '20744d9e-b05c-4e20-aced-0b23982daaf9'
---

# 森林之音

一款基于 Flutter 的多源音乐播放器，聚合网易云音乐和酷我音乐，支持搜索、播放、歌词、排行榜、歌单管理等功能。

## 功能特性

### 播放功能
- 多源搜索 — 同时搜索网易云和酷我，结果自动合并去重
- 智能换源 — 某个音源播放失败时自动尝试其他音源
- 播放模式 — 顺序播放、列表循环、单曲循环、随机播放
- 播放队列 — 支持查看、编辑、清空播放队列
- 后台播放 — 锁屏/切应用时持续播放，系统通知栏控制

### 音质与音源
- 5 档音质 — 标准(128K)、较高(192K)、极高(320K)、无损(FLAC)、Hi-Res
- 本地 VIP — 解锁 VIP 标记歌曲的高品质音源
- 多音源 — 网易云 + 酷我双音源

### 歌词
- LRC 歌词解析与实时同步
- 播放页歌词自动滚动，高亮当前行
- 点击歌词行跳转到对应位置
- 通知栏显示当前歌词

### 排行榜
- 9 大网易云官方榜单：热歌榜、新歌榜、飙升榜、ACG榜、欧美榜、日语榜、古典榜、电音榜、韩语榜
- 排行榜数据缓存，切换秒出

### 歌单管理
- 本地歌单 — 新建、重命名、删除歌单
- 歌曲管理 — 向歌单添加/移除歌曲
- 网易云导入 — 输入 UID 一键导入用户所有歌单

### 收藏与历史
- 收藏歌曲 — 一键收藏/取消收藏
- 播放历史 — 自动记录，支持查看和清除

### 下载
- 歌曲下载 — 下载 MP3 到本地
- 下载管理 — 查看、播放、删除已下载歌曲

### 搜索
- 关键词搜索 — 支持歌名、歌手、专辑
- 搜索历史 — 自动保存最近 30 条
- 热门搜索 — 推荐热门歌手

### 界面
- Material 3 设计，支持系统亮色/暗色主题
- 网易云品牌红色主题 (#EC4141)
- 黑胶唱片应用图标
- 全屏播放器 — 渐变背景、大封面、歌词视图
- 点击歌手名跳转搜索该歌手

---

## 技术架构

```
Flutter 3.44.1
├── 状态管理: Provider
├── 音频引擎: just_audio + audio_service
├── 网络请求: http
├── 本地存储: sqflite (SQLite) + shared_preferences
├── 图片缓存: cached_network_image
└── CRC32: archive
```

---

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── config.dart               # 配置常量
├── models/models.dart        # 数据模型
├── utils/lrc_parser.dart     # LRC 歌词解析
├── services/
│   ├── music_source_service.dart   # 音乐 API 服务
│   ├── player_service.dart         # 播放器服务
│   └── storage_service.dart        # 本地存储服务
└── screens/
    ├── home_screen.dart       # 首页
    ├── search_screen.dart     # 搜索页
    ├── player_screen.dart     # 播放页
    ├── play_queue_sheet.dart  # 播放队列
    ├── playlist_tab.dart      # 歌单管理
    ├── favorites_screen.dart  # 收藏页
    ├── history_screen.dart    # 历史页
    ├── downloads_screen.dart  # 下载页
    └── settings_screen.dart   # 设置页
```

---

## 构建与运行

### 环境要求
- Flutter SDK 3.44.1+
- Android SDK (API 36+)
- Dart SDK 3.12.1+

### 构建 APK

```bash
# Debug 版本
flutter build apk --debug

# Release 版本
flutter build apk --release
```

### 安装到设备

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

---

## 缓存说明

| 缓存类型 | 存储位置 | 有效期 |
|----------|----------|--------|
| 播放链接 | SQLite | 1 小时 |
| 歌词 | SQLite | 永久 |
| 搜索结果 | 内存 | 最近 20 次 |
| 排行榜 | 内存 | 本次会话 |
| 封面图片 | 磁盘 | 自动管理 |

---

## 常见问题

**Q: 有些歌曲播放不了？**
A: 部分歌曲因版权或平台限制无法播放，应用会自动跳到下一首。

**Q: 封面图片加载失败？**
A: 网易云 CDN 有防盗链机制，已通过 CachedNetworkImage + Referer Header 解决。

**Q: 后台播放被系统杀掉？**
A: 已配置前台服务和 WAKE_LOCK，一般不会被杀。如遇问题可在系统设置中关闭应用的电池优化。

---

## 许可证

仅供个人学习使用。