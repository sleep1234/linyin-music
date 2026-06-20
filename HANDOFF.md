# 森林之音 - 项目接续文档

## 项目地址
- GitHub: https://github.com/sleep1234/linyin-music
- 本地路径: /vol1/1000/9自己的软件项目/netease_music
- GitHub Token: 见服务器环境变量或密码管理器

## 当前状态

### 已完成
- [x] Flutter 多源音乐播放器核心功能（网易云+酷我双音源）
- [x] 搜索、播放、歌词、排行榜、歌单、收藏、历史、下载
- [x] 后台播放 + 锁屏控制（audio_service）
- [x] Android 本地 VIP 模式
- [x] 代码审查：修复 Song 序列化丢失字段、下载歌曲离线播放、filePath 字段
- [x] 创建 GitHub 仓库并推送代码
- [x] GitHub Actions CI/CD 配置（Android + iOS）
- [x] CarWith/CarPlay 基础配置（AndroidManifest + CarPlaySceneDelegate.swift）
- [x] 服务器 Flutter 环境配置（Flutter 3.44.2 + Android SDK 36 + NDK 28）
- [x] Android APK 本地编译成功（55.1MB）
- [x] mimo2api 项目部署（端口 4008，开机自启）

### 未完成 / 待处理
- [ ] iOS 版本实际编译（需 macOS 环境，GitHub Actions 云端编译）
- [ ] CarPlay SceneDelegate 接入实际 MediaSession 数据（目前是空壳模板）
- [ ] 无线 ADB 连接安装 APK 到手机
- [ ] CarWith 车机实际测试
- [ ] 越狱设备安装测试
- [ ] assets/ 目录缺少应用图标等资源文件
- [ ] pubspec.yaml 中 assets 目录引用报错（目录已创建但为空）

## 编译环境

| 组件 | 版本 | 路径 |
|------|------|------|
| Flutter | 3.44.2 | `/opt/flutter/` |
| Dart | 3.12.2 | Flutter 自带 |
| Android SDK | 36.0.0 | `/opt/android-sdk/` |
| NDK | 28.2.13676358 | `/opt/android-sdk/ndk/` |
| Java | 21 | `/usr/local/bin/java` |

### 编译命令
```bash
export PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH"
export ANDROID_HOME="/opt/android-sdk"
export PUB_HOSTED_URL=https://pub.dev
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export http_proxy=http://192.168.31.216:2080
export https_proxy=http://192.168.31.216:2080
cd /vol1/1000/9自己的软件项目/netease_music
flutter build apk --release
```

### 注意事项
- Gradle 不能走 HTTP 代理（dl.google.com TLS 握手失败），直连即可
- Flutter pub get 需要走代理，用 `http_proxy`/`https_proxy` 环境变量
- settings.gradle.kts 和 build.gradle.kts 不能加阿里云镜像，会和 Flutter 工具链 `FAIL_ON_PROJECT_REPOS` 冲突
- Gradle init.gradle 也不能加 allprojects 仓库，同样冲突

## 代理信息
- HTTP 代理: `192.168.31.216:2080`
- 用途: GitHub 推送、Flutter SDK 下载、pub get、Android SDK 组件下载
- 限制: 不支持 dl.google.com 的 HTTPS CONNECT 隧道

## 项目架构
```
lib/
├── main.dart                    # 入口
├── config.dart                  # 音源配置、音质枚举
├── models/models.dart           # Song/Playlist/Artist 模型
├── services/
│   ├── music_source_service.dart  # 多源搜索+URL缓存+排行榜
│   ├── player_service.dart        # 播放器+歌词同步+收藏
│   └── storage_service.dart       # SQLite+SharedPreferences 存储
├── screens/
│   ├── home_screen.dart           # 首页（排行榜）
│   ├── search_screen.dart         # 搜索
│   ├── player_screen.dart         # 播放页+歌词
│   ├── play_queue_sheet.dart      # 播放队列
│   ├── playlist_tab.dart          # 歌单管理
│   ├── favorites_screen.dart      # 收藏
│   ├── history_screen.dart        # 历史
│   ├── downloads_screen.dart      # 下载管理
│   └── settings_screen.dart       # 设置
└── utils/lrc_parser.dart          # LRC 歌词解析
```

## 关键修复记录
1. `Song.toJson/fromJson` 补全 urlId/artistId/albumId/filePath 字段
2. 新增 `Song.filePath` 字段支持离线播放
3. `player_service.dart` 优先检查本地文件再走网络
4. `downloads_screen.dart` 下载时保存完整歌曲信息
5. 添加 `dart:io` import 修复 File 未定义错误
6. 移除无效的 `android:automedia` 和错误格式的 automotive XML

## iOS CI 说明
- 工作流: `.github/workflows/build-ios.yml`
- macOS runner 无签名证书，产出 unsigned IPA
- 用巨魔/TrollStore 安装不需要签名
- 如果需要正式签名，在 GitHub Secrets 中配置 IOS_P12_BASE64、IOS_P12_PASSWORD、IOS_PROVISION_BASE64
