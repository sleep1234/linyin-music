import CarPlay
import Flutter

@available(iOS 14.0, *)
class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    var flutterEngine: FlutterEngine?
    var playlistChannel: FlutterMethodChannel?
    var currentTemplate: CPListTemplate?

    // 缓存歌曲数据
    private var songs: [[String: Any]] = []
    private var currentIndex: Int = -1

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController

        // 初始化 Flutter Engine 用于通信
        let engine = FlutterEngine(name: "carplay_engine", project: nil)
        engine.run()
        self.flutterEngine = engine

        // 建立 MethodChannel 通信
        let channel = FlutterMethodChannel(
            name: "com.xiaopeng.netease_music/carplay",
            binaryMessenger: engine.binaryMessenger
        )
        self.playlistChannel = channel

        channel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "updatePlaylist":
                if let args = call.arguments as? [String: Any] {
                    self?.updatePlaylist(args)
                }
                result(nil)
            case "updateCurrentIndex":
                if let index = call.arguments as? Int {
                    self?.updateCurrentIndex(index)
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // 显示初始列表
        showRootTemplate()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        self.interfaceController = nil
        self.currentTemplate = nil
    }

    // MARK: - 播放列表管理

    private func showRootTemplate() {
        let emptySection = CPListSection(items: [])
        let template = CPListTemplate(title: "森林之音", sections: [emptySection])
        template.delegate = self
        self.currentTemplate = template
        interfaceController?.setRootTemplate(template, animated: false)
    }

    private func updatePlaylist(_ data: [String: Any]) {
        if let songList = data["songs"] as? [[String: Any]] {
            self.songs = songList
        }
        if let index = data["currentIndex"] as? Int {
            self.currentIndex = index
        }
        rebuildTemplate()
    }

    private func updateCurrentIndex(_ index: Int) {
        self.currentIndex = index
        rebuildTemplate()
    }

    private func rebuildTemplate() {
        guard !songs.isEmpty else {
            showRootTemplate()
            return
        }

        var items: [CPListItem] = []

        for (index, song) in songs.enumerated() {
            let name = song["name"] as? String ?? "未知"
            let artist = song["artist"] as? String ?? ""
            let detailText = index == currentIndex ? "▶ \(artist)" : artist

            let item = CPListItem(text: name, detailText: detailText)
            item.handler = { [weak self] item, completion in
                self?.playSong(at: index)
                completion()
            }
            items.append(item)
        }

        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "播放列表", sections: [section])
        template.delegate = self

        self.currentTemplate = template
        interfaceController?.setRootTemplate(template, animated: true)
    }

    private func playSong(at index: Int) {
        playlistChannel?.invokeMethod("playSong", arguments: index)
        // 播放后跳转到 Now Playing
        let nowPlaying = CPNowPlayingTemplate.shared
        interfaceController?.pushTemplate(nowPlaying, animated: true)
    }
}

// MARK: - CPListTemplateDelegate

@available(iOS 14.0, *)
extension CarPlaySceneDelegate: CPListTemplateDelegate {
    func listTemplate(_ listTemplate: CPListTemplate, didSelect item: CPListItem, sectionIndex: Int, itemIndex: Int) {
        // item.handler 已经处理了点击事件
    }
}
