# 森林之音 - 安装指南

## Android APK

### 无线调试安装

1. 手机 → 设置 → 开发者选项 → 打开 **USB调试** 和 **无线调试**
2. 电脑执行：
   ```bash
   adb pair 192.168.31.216:<配对端口>    # 输入手机上显示的配对码
   adb connect 192.168.31.216:<连接端口>  # 无线调试主页上的端口
   adb install /vol1/1000/9自己的软件项目/netease_music/build/app/outputs/flutter-apk/app-release.apk
   ```

### 直接安装
把 APK 传到手机上，直接点击安装即可。

**APK 路径：**
```
/vol1/1000/9自己的软件项目/netease_music/build/app/outputs/flutter-apk/app-release.apk
```

---

## iOS (CarPlay)

iOS 版本通过 GitHub Actions 云端编译，需 macOS runner。

### 编译流程
1. 代码已推送到 `https://github.com/sleep1234/linyin-music`
2. iOS CI 工作流已配置：`.github/workflows/build-ios.yml`
3. 推送 tag 触发编译：
   ```bash
   cd /vol1/1000/9自己的软件项目/netease_music
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. 在 GitHub Actions 页面下载 IPA artifact

### 无签名安装（巨魔/越狱）
- IPA 下载后用 **TrollStore** 或 **Sideloadly** 安装
- 无需 Apple 开发者账号

---

## 功能说明

| 平台 | CarWith/CarPlay | 说明 |
|------|----------------|------|
| Android | CarWith (Android Auto) | 通过 MediaBrowserService 自动被车机识别 |
| iOS | CarPlay | 通过 CPApplicationDelegate 实现车机界面 |

### CarWith 连接
手机通过 USB 或蓝牙连接小米车机后，森林之音会自动出现在车机媒体列表中。

### CarPlay 连接
iPhone 通过 CarPlay 连接车机后，森林之音会自动出现在 CarPlay 应用列表中。

---

## 编译环境（服务器已配置）

| 组件 | 版本 | 路径 |
|------|------|------|
| Flutter | 3.44.2 | `/opt/flutter/` |
| Android SDK | 36.0.0 | `/opt/android-sdk/` |
| NDK | 28.2.13676358 | `/opt/android-sdk/ndk/` |
| Java | 21 | 系统自带 |

### 本地编译命令
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
