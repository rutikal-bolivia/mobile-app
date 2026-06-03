import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerAssetResolver(engineBridge.pluginRegistry)
  }

  // Canal que devuelve la ruta absoluta de un asset dentro del bundle de la
  // app. En iOS los assets son ficheros reales, así que el `.mbtiles` se puede
  // leer directo desde el bundle sin copiar 191 MB al sandbox.
  private func registerAssetResolver(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "RutikalAssetResolver") else { return }
    let channel = FlutterMethodChannel(
      name: "rutikal/assets",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "resolveAssetPath",
            let asset = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      let key = FlutterDartProject.lookupKey(forAsset: asset)
      result(Bundle.main.path(forResource: key, ofType: nil))
    }
  }
}
