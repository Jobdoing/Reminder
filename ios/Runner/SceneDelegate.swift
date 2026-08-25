import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // NOTE(ceiling): This explicit engine bypasses Flutter issue #190030 on iOS 26
  // ProMotion devices. Remove it only after upstream fixes cold launch and the
  // physical-device regression check passes.
  // Source: https://github.com/flutter/flutter/issues/190030
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard
      let windowScene = scene as? UIWindowScene,
      let appDelegate = UIApplication.shared.delegate as? AppDelegate
    else { return }

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = FlutterViewController(
      engine: appDelegate.flutterEngine,
      nibName: nil,
      bundle: nil
    )
    self.window = window
    window.makeKeyAndVisible()
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
