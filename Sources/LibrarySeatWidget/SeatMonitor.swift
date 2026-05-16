import AppKit
import Foundation

@MainActor
final class SeatMonitor: ObservableObject {
    static let shared = SeatMonitor()

    @Published private(set) var snapshot: SeatSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdate: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var needsLogin = true

    private let client = SeatWebClient()
    private let defaults = UserDefaults.standard
    private var timer: Timer?
    private var didStart = false
    private var hasSeenSuccessfulSession: Bool {
        get { defaults.bool(forKey: "hasSeenSuccessfulSession") }
        set { defaults.set(newValue, forKey: "hasSeenSuccessfulSession") }
    }

    private init() {
        client.onResult = { [weak self] result in
            self?.handle(result)
        }
    }

    var menuBarTitle: String {
        if let snapshot {
            return "SIP \(snapshot.totalFree)"
        }

        return "SIP --"
    }

    var lastUpdateText: String {
        guard let lastUpdate else {
            return "尚未成功刷新"
        }

        return Self.timeFormatter.string(from: lastUpdate)
    }

    func start() {
        guard !didStart else { return }

        didStart = true
        if hasSeenSuccessfulSession {
            refresh()
        } else {
            showLogin()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        timer?.tolerance = 10
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !isRefreshing else { return }

        isRefreshing = true
        lastError = nil
        client.refresh()
    }

    func showLogin() {
        needsLogin = true
        client.showLoginWindow()
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func handle(_ result: Result<SeatSnapshot, SeatFetchFailure>) {
        isRefreshing = false

        switch result {
        case .success(let snapshot):
            guard !snapshot.floors.isEmpty else {
                needsLogin = true
                lastError = SeatFetchFailure.noSeatData.localizedDescription
                return
            }

            self.snapshot = snapshot
            lastUpdate = Date()
            lastError = nil
            needsLogin = false
            hasSeenSuccessfulSession = true
            client.hideLoginWindow()

        case .failure(let failure):
            needsLogin = true
            lastError = failure.localizedDescription
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
