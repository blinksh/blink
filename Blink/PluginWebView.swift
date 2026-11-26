import SwiftUI
import WebKit

private final class PluginAssets: NSObject, WKURLSchemeHandler {
  let package: PluginPackage
  init(package: PluginPackage) { self.package = package }

  func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
    do {
      guard let url = task.request.url, url.host == package.manifest.id, task.request.httpMethod == "GET" else {
        throw PluginPackage.Failure.invalid("Invalid resource request")
      }
      let path = String(url.path.dropFirst())
      let file = try package.asset(path)
      let attributes = try file.resourceValues(forKeys: [.fileSizeKey])
      guard (attributes.fileSize ?? Int.max) <= 8 * 1024 * 1024 else { throw PluginPackage.Failure.invalid("Asset exceeds 8 MiB") }
      let data = try Data(contentsOf: file)
      let types = ["html": "text/html", "js": "text/javascript", "css": "text/css", "json": "application/json",
                   "png": "image/png", "jpg": "image/jpeg", "svg": "image/svg+xml", "woff2": "font/woff2"]
      let csp = "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'none'; media-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'"
      let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
        "Content-Type": types[file.pathExtension] ?? "application/octet-stream",
        "Content-Security-Policy": csp, "X-Content-Type-Options": "nosniff"
      ])!
      task.didReceive(response); task.didReceive(data); task.didFinish()
    } catch { task.didFailWithError(error) }
  }
  func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

struct PluginWebView: UIViewRepresentable {
  let package: PluginPackage

  func makeCoordinator() -> Coordinator { Coordinator(package: package) }

  func makeUIView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    config.setURLSchemeHandler(PluginAssets(package: package), forURLScheme: "blink-plugin")
    let content = config.userContentController
    content.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "blink")
    content.addUserScript(WKUserScript(source: Self.sdk, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    let webView = WKWebView(frame: .zero, configuration: config)
    webView.navigationDelegate = context.coordinator
    var url = URLComponents()
    url.scheme = "blink-plugin"
    url.host = package.manifest.id
    url.path = "/" + package.manifest.entry
    if let entry = url.url { webView.load(URLRequest(url: entry)) }
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {}

  static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
    webView.configuration.userContentController.removeScriptMessageHandler(forName: "blink", contentWorld: .page)
    webView.navigationDelegate = nil
    webView.stopLoading()
  }

  final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandlerWithReply {
    private let package: PluginPackage

    init(package: PluginPackage) { self.package = package }

    private func isOwnOrigin(_ url: URL?) -> Bool {
      url?.scheme == "blink-plugin" && url?.host == package.manifest.id
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
      decisionHandler(action.targetFrame?.isMainFrame == true && isOwnOrigin(action.request.url) ? .allow : .cancel)
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
      guard message.frameInfo.isMainFrame, isOwnOrigin(message.frameInfo.request.url),
            let request = message.body as? [String: Any], let method = request["method"] as? String else {
        replyHandler(nil, "Invalid request")
        return
      }

      let manifest = package.manifest
      let hasStorage = manifest.permissions.contains("storage")
      if method == "host.info" {
        replyHandler(["apiVersion": 1, "host": "blink", "platform": "ios", "pluginID": manifest.id,
                      "capabilities": ["host.info"] + (hasStorage ? ["storage.get", "storage.set"] : [])], nil)
        return
      }

      guard hasStorage, let key = request["key"] as? String, !key.isEmpty, key.utf8.count <= 256 else {
        replyHandler(nil, "Permission denied or invalid key")
        return
      }
      let namespace = "plugin.v1." + manifest.id
      var values = UserDefaults.standard.dictionary(forKey: namespace) as? [String: String] ?? [:]
      switch method {
      case "storage.get":
        replyHandler(values[key] ?? NSNull(), nil)
      case "storage.set":
        guard let value = request["value"] as? String else { replyHandler(nil, "Value must be a string"); return }
        values[key] = value
        guard let data = try? JSONSerialization.data(withJSONObject: values), data.count <= 65536 else {
          replyHandler(nil, "Storage quota exceeded (64 KiB)")
          return
        }
        UserDefaults.standard.set(values, forKey: namespace)
        replyHandler(true, nil)
      default:
        replyHandler(nil, "Unsupported method")
      }
    }
  }

  private static let sdk = """
  (() => {
    const call = (method, args = {}) => window.webkit.messageHandlers.blink.postMessage({method, ...args});
    Object.defineProperty(window, 'blink', {value: Object.freeze({
      apiVersion: 1,
      host: Object.freeze({info: () => call('host.info')}),
      storage: Object.freeze({get: key => call('storage.get', {key}), set: (key, value) => call('storage.set', {key, value})})
    }), writable: false, configurable: false});
  })();
  """
}
