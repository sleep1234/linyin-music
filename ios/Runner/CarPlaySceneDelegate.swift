import CarPlay

@available(iOS 14.0, *)
class CarPlaySceneDelegate: NSObject, CPApplicationDelegate {

    var interfaceController: CPInterfaceController?

    func application(
        _ application: UIApplication,
        didConnectCarInterfaceController interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        let rootList = CPListTemplate(title: "森林之音", sections: [])
        interfaceController.setRootTemplate(rootList, animated: true)
    }

    func application(
        _ application: UIApplication,
        didDisconnectCarInterfaceController interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        self.interfaceController = nil
    }
}
