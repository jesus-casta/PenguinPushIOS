import SwiftUI
import WebKit

struct GameView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = GameWebModel()

    var body: some View {
        ZStack {
            GameWebView(model: model)
            if model.failed {
                VStack(spacing: 16) {
                    Text("No se ha podido abrir el juego.")
                    Button("Reintentar") { model.load() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { model.pause() }
        }
    }
}

final class GameWebModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var failed = false
    let webView: WKWebView
    private var gameDirectory: URL?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.918, green: 0.957, blue: 0.973, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.bounces = false
        load()
    }

    func load() {
        failed = false
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Game") else {
            failed = true
            return
        }
        gameDirectory = url.deletingLastPathComponent()
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func pause() {
        webView.evaluateJavaScript("window.PenguinPush && window.PenguinPush.pause()", completionHandler: nil)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, let directory = gameDirectory,
              url.isFileURL, url.standardizedFileURL.path.hasPrefix(directory.standardizedFileURL.path + "/") else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { failed = true }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { failed = true }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { load() }
}

struct GameWebView: UIViewRepresentable {
    @ObservedObject var model: GameWebModel
    func makeUIView(context: Context) -> WKWebView { model.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
