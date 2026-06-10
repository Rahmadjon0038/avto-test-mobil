import Flutter
import GoogleSignIn
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureGoogleSignIn()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func configureGoogleSignIn() {
    guard let clientId = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
          !clientId.isEmpty else {
      return
    }

    let serverClientId = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String
    if let serverClientId, !serverClientId.isEmpty {
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(
        clientID: clientId,
        serverClientID: serverClientId
      )
    } else {
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
  }
}
