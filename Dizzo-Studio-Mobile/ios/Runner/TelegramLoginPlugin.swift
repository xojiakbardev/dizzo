import Flutter
import TelegramLogin
import UIKit

/// Native "Log in with Telegram" (the TelegramLogin Swift package) behind the
/// `uz.dizzo/telegram_login` channel. Dart side:
/// `lib/features/auth/data/telegram_native_login.dart`.
///
/// - `init {clientId, redirectUri, scopes}`
/// - `login` → the id_token (String), nil when cancelled/superseded, or an
///   error (`not_configured`, `failed`).
/// - `cancel` → completes a pending `login` with nil.
///
/// The SDK opens Telegram, or its own ASWebAuthenticationSession sheet when
/// Telegram isn't installed. Telegram returns through the universal link
/// `https://app{id}-login.tg.dev` (Associated Domains, Runner.entitlements),
/// which the scene delegate hooks below hand to `TelegramLogin.handle`.
final class TelegramLoginPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  static let channelName = "uz.dizzo/telegram_login"

  private var callbackHost: String?
  private var pending: FlutterResult?
  /// Bumped on every login, so a superseded SDK completion is ignored.
  private var attempt = 0

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = TelegramLoginPlugin()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "init":
      let args = call.arguments as? [String: Any] ?? [:]
      let clientId = args["clientId"] as? String ?? ""
      let redirectUri = args["redirectUri"] as? String ?? ""
      let scopes = args["scopes"] as? [String] ?? ["openid", "profile"]
      guard !clientId.isEmpty, let host = URL(string: redirectUri)?.host else {
        result(FlutterError(code: "not_configured", message: "clientId/redirectUri missing", details: nil))
        return
      }
      // Channel calls arrive on the main thread.
      MainActor.assumeIsolated {
        TelegramLogin.configure(clientId: clientId, redirectUri: redirectUri, scopes: scopes)
      }
      callbackHost = host
      result(nil)
    case "login":
      guard callbackHost != nil else {
        result(FlutterError(code: "not_configured", message: "init was not called", details: nil))
        return
      }
      finish(nil)  // a newer attempt replaces an older one ("open again")
      attempt += 1
      let current = attempt
      pending = result
      MainActor.assumeIsolated {
        TelegramLogin.login { [weak self] outcome in
          DispatchQueue.main.async {
            self?.complete(outcome, attempt: current)
          }
        }
      }
    case "cancel":
      attempt += 1
      finish(nil)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func complete(_ outcome: Result<LoginData, Error>, attempt current: Int) {
    guard current == attempt else { return }
    switch outcome {
    case .success(let data):
      finish(data.idToken)
    case .failure(let error as TelegramLoginError) where error == .cancelled:
      finish(nil)
    case .failure(let error):
      NSLog("Telegram login failed: \(error.localizedDescription)")
      fail(error.localizedDescription)
    }
  }

  private func finish(_ idToken: String?) {
    guard let result = pending else { return }
    pending = nil
    result(idToken)
  }

  private func fail(_ message: String) {
    guard let result = pending else { return }
    pending = nil
    result(FlutterError(code: "failed", message: message, details: nil))
  }

  /// True when `url` is the Telegram login callback.
  private func handleCallback(_ url: URL?) -> Bool {
    guard let url, let host = callbackHost,
      url.host?.caseInsensitiveCompare(host) == .orderedSame
    else { return false }
    Task { @MainActor in TelegramLogin.handle(url) }
    return true
  }

  // MARK: - Scene life cycle (the app uses UIScene / FlutterSceneDelegate)

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else { return false }
    return handleCallback(userActivity.webpageURL)
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    URLContexts.contains { handleCallback($0.url) }
  }

  // MARK: - App delegate (in case the scene delegate isn't used)

  func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([Any]) -> Void
  ) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else { return false }
    return handleCallback(userActivity.webpageURL)
  }
}
