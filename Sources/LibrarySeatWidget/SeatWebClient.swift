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
        loadHome()
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

            var decodedSnapshot: SeatSnapshot?

            if let json = value as? String,
               let data = json.data(using: .utf8),
               let snapshot = try? JSONDecoder().decode(SeatSnapshot.self, from: data) {
                decodedSnapshot = snapshot

                if snapshot.status == "ok", !snapshot.floors.isEmpty {
                    self.onResult?(.success(snapshot))
                    return
                }
            }

            if attempt < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.runExtractionAttempt(generation: generation, attempt: attempt + 1)
                }
            } else {
                self.onResult?(.failure(Self.failure(from: decodedSnapshot)))
            }
        }
    }

    private static func failure(from snapshot: SeatSnapshot?) -> SeatFetchFailure {
        guard let snapshot else {
            return .noSeatData
        }

        switch snapshot.status {
        case "login":
            return .loginRequired
        case "mismatch":
            return .inconsistentData(snapshot.message ?? "楼层合计与 SIP Campus 总数不同")
        default:
            return .noSeatData
        }
    }

    private static let extractSeatScript = """
    (() => {
      const wantedFloors = ["3F-North", "4F", "5F", "7F", "8F", "10F"];
      const body = (document.body && document.body.innerText ? document.body.innerText : "");
      const normalizedBody = normalizeText(body);
      const pageTitle = document.title || "";

      function normalizeText(value) {
        return String(value || "")
          .replace(/\\u00a0/g, " ")
          .replace(/[ \\t]+/g, " ")
          .replace(/\\n+/g, "\\n")
          .trim();
      }

      function escapeRegExp(value) {
        return value.replace(/[.*+?^${}()|[\\]\\\\]/g, "\\\\$&");
      }

      function isVisible(element) {
        if (!element || !element.getBoundingClientRect) {
          return false;
        }

        const style = window.getComputedStyle(element);

        if (
          style.display === "none" ||
          style.visibility === "hidden" ||
          Number.parseFloat(style.opacity || "1") === 0
        ) {
          return false;
        }

        const rects = Array.from(element.getClientRects());
        return rects.some((rect) => rect.width > 0 && rect.height > 0);
      }

      function floorBoundaryPattern(floor) {
        return new RegExp("(^|[^A-Za-z0-9-])" + escapeRegExp(floor) + "([^A-Za-z0-9-]|$)");
      }

      function parseCampusTotal() {
        const match = normalizedBody.match(/SIP\\s+Campus\\s*\\(\\s*(\\d+)\\s*\\/\\s*(\\d+)\\s*\\)/i);

        if (!match) {
          return { campusFree: null, campusTotal: null };
        }

        return {
          campusFree: Number.parseInt(match[1], 10),
          campusTotal: Number.parseInt(match[2], 10)
        };
      }

      function parseFloor(floor, elements) {
        const floorPattern = floorBoundaryPattern(floor);
        const candidates = [];

        for (const element of elements) {
          const text = normalizeText(element.innerText || element.textContent || "");

          if (
            text.length < floor.length + 10 ||
            text.length > 260 ||
            !floorPattern.test(text) ||
            !/Free\\s*\\d+/i.test(text) ||
            !/Total\\s*\\d+/i.test(text)
          ) {
            continue;
          }

          const valueMatch = text.match(/Free\\s*(\\d+)[\\s\\S]{0,100}?Total\\s*(\\d+)/i);

          if (!valueMatch) {
            continue;
          }

          candidates.push({
            name: floor,
            free: Number.parseInt(valueMatch[1], 10),
            total: Number.parseInt(valueMatch[2], 10),
            score: text.length
          });
        }

        candidates.sort((left, right) => left.score - right.score);
        return candidates[0] || null;
      }

      const visibleElements = Array.from(document.body ? document.body.querySelectorAll("*") : [])
        .filter(isVisible);
      const floors = wantedFloors
        .map((floor) => parseFloor(floor, visibleElements))
        .filter(Boolean)
        .map(({ name, free, total }) => ({ name, free, total }));

      const totalFree = floors.reduce((sum, floor) => sum + floor.free, 0);
      const totalSeats = floors.reduce((sum, floor) => sum + floor.total, 0);
      const { campusFree, campusTotal } = parseCampusTotal();
      const looksLikeLogin = /login|登录|统一身份|统一认证|sign in|password|密码/i.test(normalizedBody + " " + pageTitle);
      let status = "ok";
      let message = null;

      if (looksLikeLogin && floors.length === 0) {
        status = "login";
        message = "当前页面看起来是登录页";
      } else if (floors.length !== wantedFloors.length) {
        status = "empty";
        message = `只读取到 ${floors.length}/${wantedFloors.length} 个 SIP 楼层卡片`;
      } else if (
        campusFree !== null &&
        campusTotal !== null &&
        (campusFree !== totalFree || campusTotal !== totalSeats)
      ) {
        status = "mismatch";
        message = `楼层合计 ${totalFree}/${totalSeats}，页面总数 ${campusFree}/${campusTotal}`;
      }

      return JSON.stringify({
        status,
        floors,
        totalFree,
        totalSeats,
        campusFree,
        campusTotal,
        message,
        pageTitle
      });
    })();
    """
}
