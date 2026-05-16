import AppKit
import Foundation
import WebKit

@MainActor
final class SeatWebClient: NSObject, WKNavigationDelegate {
    var onResult: ((Result<SeatSnapshot, SeatFetchFailure>) -> Void)?

    private let homeURL = URL(string: "https://seatbookings.xjtlu.edu.cn/#/ic/home")!
    private let webView: WKWebView
    private var window: NSWindow?
    private var extractionGeneration = 0

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()

        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    }

    func showLoginWindow() {
        if window == nil {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1080, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "图书馆预约系统登录"
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            newWindow.contentView = webView
            window = newWindow
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if webView.url == nil {
            loadHome()
        } else {
            scheduleExtractionAttempts()
        }
    }

    func hideLoginWindow() {
        window?.orderOut(nil)
    }

    func refresh() {
        if webView.url == nil {
            loadHome()
            return
        }

        webView.reload()
    }

    private func loadHome() {
        let request = URLRequest(
            url: homeURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        webView.load(request)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        scheduleExtractionAttempts()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onResult?(.failure(.loadFailed(error.localizedDescription)))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onResult?(.failure(.loadFailed(error.localizedDescription)))
    }

    private func scheduleExtractionAttempts() {
        extractionGeneration += 1
        runExtractionAttempt(generation: extractionGeneration, attempt: 1)
    }

    private func runExtractionAttempt(generation: Int, attempt: Int) {
        guard generation == extractionGeneration else { return }

        webView.evaluateJavaScript(Self.extractSeatScript) { [weak self] value, error in
            guard let self else { return }

            if generation != self.extractionGeneration {
                return
            }

            if let error {
                self.onResult?(.failure(.javascriptFailed(error.localizedDescription)))
                return
            }

            if let json = value as? String,
               let data = json.data(using: .utf8),
               let snapshot = try? JSONDecoder().decode(SeatSnapshot.self, from: data),
               snapshot.status == "ok",
               !snapshot.floors.isEmpty {
                self.onResult?(.success(snapshot))
                return
            }

            if attempt < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.runExtractionAttempt(generation: generation, attempt: attempt + 1)
                }
            } else {
                self.onResult?(.failure(.loginRequired))
            }
        }
    }

    private static let extractSeatScript = """
    (() => {
      const wantedFloors = ["3F-North", "4F", "5F", "7F", "8F", "10F"];
      const body = (document.body && document.body.innerText ? document.body.innerText : "")
        .replace(/\\u00a0/g, " ")
        .replace(/[ \\t]+/g, " ");
      const pageTitle = document.title || "";

      function escapeRegExp(value) {
        return value.replace(/[.*+?^${}()|[\\]\\\\]/g, "\\\\$&");
      }

      function parseFloors(section) {
        const floors = [];

        for (const floor of wantedFloors) {
          const pattern = new RegExp(escapeRegExp(floor) + "[\\\\s\\\\S]{0,160}?Free\\\\s*(\\\\d+)[\\\\s\\\\S]{0,120}?Total\\\\s*(\\\\d+)", "i");
          const match = section.match(pattern);

          if (match) {
            floors.push({
              name: floor,
              free: Number.parseInt(match[1], 10),
              total: Number.parseInt(match[2], 10)
            });
          }
        }

        return floors;
      }

      const candidates = [body];
      let searchFrom = 0;

      while (true) {
        const sipIndex = body.indexOf("SIP Campus", searchFrom);

        if (sipIndex < 0) {
          break;
        }

        const taicangIndex = body.indexOf("Taicang Campus", sipIndex + 1);
        candidates.push(body.slice(sipIndex, taicangIndex > sipIndex ? taicangIndex : undefined));
        searchFrom = sipIndex + "SIP Campus".length;
      }

      const floors = candidates
        .map(parseFloors)
        .sort((left, right) => right.length - left.length)[0] || [];

      const totalFree = floors.reduce((sum, floor) => sum + floor.free, 0);
      const totalSeats = floors.reduce((sum, floor) => sum + floor.total, 0);
      const looksLikeLogin = /login|登录|统一身份|统一认证|sign in|password|密码/i.test(body + " " + pageTitle);

      return JSON.stringify({
        status: floors.length > 0 ? "ok" : (looksLikeLogin ? "login" : "empty"),
        floors,
        totalFree,
        totalSeats,
        pageTitle
      });
    })();
    """
}
