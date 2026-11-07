import Flutter
import Security
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
    // Le même canal que sur Android : l'identifiant du pilote et le modèle du téléphone.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ChachaDevice") else { return }
    let channel = FlutterMethodChannel(name: "chacha243/device", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "info" else { return result(FlutterMethodNotImplemented) }
      let device = UIDevice.current
      result([
        "id": DeviceId.value,
        "brand": "Apple",
        "manufacturer": "Apple",
        "model": DeviceId.model,
        "os": "\(device.systemName) \(device.systemVersion)",
      ])
    }
  }
}

/// Un identifiant gardé dans le trousseau : il reste même si le jeu est désinstallé puis réinstallé,
/// comme l'identifiant Android, pour retrouver le nom du pilote et son point de reprise.
enum DeviceId {
  private static let account = "chacha243.player"

  static var value: String {
    if let saved = read() { return saved }
    let id = UUID().uuidString.lowercased()
    write(id)
    return id
  }

  /// Le modèle exact (« iPhone15,2 »), ou celui que le simulateur imite.
  static var model: String {
    if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return sim }
    var info = utsname()
    uname(&info)
    return withUnsafePointer(to: &info.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
    }
  }

  private static func read() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  private static func write(_ id: String) {
    let item: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: account,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
      kSecValueData as String: Data(id.utf8),
    ]
    SecItemAdd(item as CFDictionary, nil)
  }
}
