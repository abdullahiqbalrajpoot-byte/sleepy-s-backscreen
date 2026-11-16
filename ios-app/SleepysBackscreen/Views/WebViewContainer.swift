import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()

        // Inject the iOS Bridge shim so window.AndroidBridge works transparently
        let bridgeScriptSource = """
        (function() {
            window.__iosBleConnected = false;
            window.AndroidBridge = {
                isBleConnected: function() {
                    return window.__iosBleConnected;
                },
                startScan: function() {
                    window.webkit.messageHandlers.iosBridge.postMessage({ action: 'startScan' });
                },
                disconnect: function() {
                    window.webkit.messageHandlers.iosBridge.postMessage({ action: 'disconnect' });
                },
                sendTrack: function(title, artist, album, duration, artworkUrl) {
                    window.webkit.messageHandlers.iosBridge.postMessage({
                        action: 'sendTrack',
                        title: title,
                        artist: artist,
                        album: album,
                        duration: duration,
                        artworkUrl: artworkUrl
                    });
                },
                sendCustomText: function(text) {
                    window.webkit.messageHandlers.iosBridge.postMessage({
                        action: 'sendCustomText',
                        text: text
                    });
                },
                showToast: function(message) {
                    window.webkit.messageHandlers.iosBridge.postMessage({
                        action: 'showToast',
                        message: message
                    });
                },
                getBatteryLevel: function() {
                    return 90;
                }
            };
            console.log("Sleepy's Backscreen iOS Bridge initialized.");
        })();
        """

        let userScript = WKUserScript(source: bridgeScriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        contentController.add(context.coordinator, name: "iosBridge")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1.0)
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator

        context.coordinator.webView = webView
        context.coordinator.setupListeners()

        // Load the local Web/index.html bundle
        if let webFolder = Bundle.main.url(forResource: "Web", withExtension: nil) {
            let indexUrl = webFolder.appendingPathComponent("index.html")
            webView.loadFileURL(indexUrl, allowingReadAccessTo: webFolder)
        } else if let indexUrl = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(indexUrl, allowingReadAccessTo: indexUrl.deletingLastPathComponent())
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // ── Coordinator ──────────────────────────────────────────────────────────

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebViewContainer
        weak var webView: WKWebView?

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func setupListeners() {
            // BLE connection state changed callback
            BLEManager.shared.onStateChanged = { [weak self] isConnected, deviceName in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let js = """
                    window.__iosBleConnected = \(isConnected);
                    if (typeof window.onNativeBleState === 'function') {
                        window.onNativeBleState(\(isConnected), '\(deviceName ?? "SMART_BACKPACK_DISPLAY")');
                    }
                    """
                    self.webView?.evaluateJavaScript(js, completionHandler: nil)
                }
            }

            // System music track changed callback
            MusicObserver.shared.onTrackChanged = { [weak self] title, artist, album, duration, position, isPlaying, artworkUrl in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let safeTitle = title.replacingOccurrences(of: "'", with: "\\'")
                    let safeArtist = artist.replacingOccurrences(of: "'", with: "\\'")
                    let safeAlbum = album.replacingOccurrences(of: "'", with: "\\'")
                    let safeArt = artworkUrl ?? ""

                    let js = """
                    if (typeof window.onNativeTrackChanged === 'function') {
                        window.onNativeTrackChanged(
                            '\(safeTitle)',
                            '\(safeArtist)',
                            '\(safeAlbum)',
                            \(duration),
                            \(position),
                            \(isPlaying),
                            '\(safeArt)'
                        );
                    }
                    """
                    self.webView?.evaluateJavaScript(js, completionHandler: nil)
                }
            }
        }

        // ── WKScriptMessageHandler ───────────────────────────────────────────

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "iosBridge",
                  let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            switch action {
            case "startScan":
                BLEManager.shared.startScan()

            case "disconnect":
                BLEManager.shared.disconnect()

            case "sendTrack":
                let title = body["title"] as? String ?? ""
                let artist = body["artist"] as? String ?? ""
                let album = body["album"] as? String ?? ""
                let duration = body["duration"] as? Int64 ?? 0
                let artworkUrl = body["artworkUrl"] as? String

                var image: UIImage? = nil
                if let art = artworkUrl, art.hasPrefix("data:image") {
                    if let range = art.range(of: "base64,") {
                        let base64 = String(art[range.upperBound...])
                        if let data = Data(base64Encoded: base64) {
                            image = UIImage(data: data)
                        }
                    }
                }

                BLEManager.shared.sendMetadata(
                    title: title,
                    artist: artist,
                    album: album,
                    duration: duration,
                    artwork: image
                )

            case "sendCustomText":
                if let text = body["text"] as? String {
                    BLEManager.shared.sendCustomText(text: text)
                }

            case "showToast":
                // iOS UI feedback
                if let msg = body["message"] as? String {
                    print("[UI Toast]: \(msg)")
                }

            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Re-sync initial state
            let isConnected = BLEManager.shared.isConnected
            let js = "window.__iosBleConnected = \(isConnected);"
            webView.evaluateJavaScript(js, completionHandler: nil)
            MusicObserver.shared.fetchCurrentTrack()
        }
    }
}
