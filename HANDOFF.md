---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '333d51a9-db01-4229-a815-d410ab313992'
  PropagateID: '333d51a9-db01-4229-a815-d410ab313992'
  ReservedCode1: 'bd7d20dd-b98f-45dc-8c53-381a3a9d55c0'
  ReservedCode2: 'bd7d20dd-b98f-45dc-8c53-381a3a9d55c0'
---

# 森林之音 - 开发接续文档

> 最后更新：2026-06-19

## 项目概况

- **App 名称：** 森林之音
- **包名：** `com.xiaopeng.netease_music`
- **技术栈：** Flutter 3.44.1 + Dart 3.12.1
- **状态：** 功能基本完成，可日常使用

---

## 构建与部署

```bash
# 构建 debug APK
cd C:\Users\zhp\Desktop\netease_music
C:\flutter\bin\flutter.bat build apk --debug

# 安装到设备
C:\Android\Sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-debug.apk

# 查看日志
C:\Android\Sdk\platform-tools\adb.exe logcat -s flutter
```

---

## 架构概览

```
lib/
├── main.dart                 # 入口，MultiProvider 注册三个 Service
├── config.dart               # 配置：AudioQuality 枚举、MusicSource 模型
├── models/models.dart        # 数据模型：Song, Playlist, Artist 等
├── utils/lrc_parser.dart     # LRC 歌词解析器
├── services/
│   ├── music_source_service.dart   # 音乐 API 客户端（搜索/播放链接/歌词/封面/排行榜/歌单导入）
│   ├── player_service.dart         # 播放引擎（just_audio + audio_service + 歌词同步）
│   └── storage_service.dart        # 本地存储（SQLite 7 张表 + SharedPreferences）
└── screens/
    ├── home_screen.dart       # 首页（发现/歌单/我的 三 Tab）
    ├── search_screen.dart     # 搜索页（多源搜索 + 历史 + 热词）
    ├── player_screen.dart     # 全屏播放器（封面/歌词/控制）
    ├── play_queue_sheet.dart  # 播放队列底部弹窗
    ├── playlist_tab.dart      # 歌单管理 + 网易云导入
    ├── favorites_screen.dart  # 收藏列表
    ├── history_screen.dart    # 播放历史
    ├── downloads_screen.dart  # 下载管理
    └── settings_screen.dart   # 设置页
```

---

## API 说明

### 1. GD Studio 聚合 API（搜索/播放链接/歌词/封面）

- **地址：** `https://music-api.gdstudio.xyz/api.php`
- **方法：** GET
- **关键：** 所有请求必须带 `s` 参数（CRC32 校验）

| types | 用途 | 必要参数 |
|-------|------|----------|
| `search` | 搜索 | `name`, `count`, `pages`, `source` |
| `url` | 播放链接 | `id`, `source`, `br` |
| `lyric` | 歌词 | `id`, `source` |
| `pic` | 封面URL | `id`, `source` |

**CRC32 计算方式：**
```dart
import 'package:archive/archive.dart';
int s = getCrc32(urlEncode(mainValue).codeUnits);
// urlEncode = encodeURIComponent + 替换 ( ) * ' !
```

**source 参数：** `netease`（网易云）、`kuwo`（酷我）

### 2. 网易云官方 API（排行榜/歌单导入）

- **方法：** GET
- **必须 Header：** `User-Agent` + `Referer: https://music.163.com`

| 接口 | 用途 |
|------|------|
| `https://music.163.com/api/v6/playlist/detail?id={id}` | 获取排行榜/歌单详情 |
| `https://music.163.com/api/user/playlist?uid={uid}&limit=50` | 获取用户歌单列表 |

**排行榜 ID：**
| 名称 | ID |
|------|-----|
| 热歌榜 | 3778678 |
| 新歌榜 | 3779629 |
| 飙升榜 | 19723756 |
| ACG榜 | 71385702 |
| 欧美榜 | 2809513713 |
| 日语榜 | 5059644681 |
| 古典榜 | 71384707 |
| 电音榜 | 1978921795 |
| 韩语榜 | 745956260 |

---

## 数据库表结构（SQLite v4）

| 表名 | 用途 | 过期策略 |
|------|------|----------|
| `favorites` | 收藏歌曲 | 永久 |
| `history` | 播放历史 | 最多 200 条 |
| `url_cache` | 播放链接缓存 | 1 小时 |
| `lyric_cache` | 歌词缓存 | 永久 |
| `playlists` | 本地歌单 | 永久 |
| `playlist_songs` | 歌单内歌曲 | 跟随歌单 |
| `downloads` | 下载记录 | 永久 |

**SharedPreferences：**
- `player_playlist` / `player_playlist_index` — 播放队列持久化
- `search_history` — 搜索历史（最多 30 条）

---

## 缓存体系

| 类型 | 位置 | 有效期 |
|------|------|--------|
| 播放链接 | SQLite `url_cache` | 1 小时 |
| 歌词 | SQLite `lyric_cache` | 永久 |
| 搜索结果 | 内存 LinkedHashMap | 最近 20 次 |
| 排行榜 | 内存 Map | 本次会话 |
| 封面图片 | CachedNetworkImage 磁盘 | 自动管理 |

---

## 已知问题与注意事项

### 封面图片 403
- 网易云 CDN 有防盗链，必须用 `CachedNetworkImage` + `httpHeaders` 发送 `Referer: https://music.163.com`
- **不能用 `Image.network`**，它不会携带自定义 headers

### 部分歌曲无法播放
- 有些歌曲在所有平台都没有版权/已下架，API 返回空 URL
- 已实现：播放失败自动跳下一首
- 未来可优化：在列表中标记不可播放的歌曲

### API 限制
- GD Studio 的 POST 接口对国内 IP 不稳定，排行榜/歌单已改用网易云官方 API
- GD Studio 的 `userlist` 类型已废弃，歌单导入改用网易云官方 API
- 搜索/播放链接/歌词/封面仍用 GD Studio GET 接口

### audio_service 初始化
- `MainActivity` 必须继承 `AudioServiceFragmentActivity`（不是 `FlutterActivity`）
- AndroidManifest 需要 `tools:ignore="Instantiatable"` 注解

---

## 未来可扩展功能

1. **歌词翻译** — API 已支持 `tlyric` 字段，前端未实现
2. **多语言** — 当前仅中文
3. **桌面歌词** — audio_service 支持但前端未实现
4. **均衡器** — just_audio 支持 Android Equalizer
5. **歌曲标签/分类** — 按风格、心情分类
6. **推荐算法** — 基于播放历史推荐
7. **跨设备同步** — 收藏/歌单云端同步