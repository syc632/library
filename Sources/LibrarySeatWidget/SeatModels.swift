import Foundation

struct FloorSeat: Codable, Identifiable, Equatable {
    let name: String
    let free: Int
    let total: Int

    var id: String { name }
}

struct SeatSnapshot: Codable, Equatable {
    let status: String
    let floors: [FloorSeat]
    let totalFree: Int
    let totalSeats: Int
    let campusFree: Int?
    let campusTotal: Int?
    let message: String?
    let pageTitle: String?
}

enum SeatFetchFailure: Error, LocalizedError {
    case loadFailed(String)
    case javascriptFailed(String)
    case loginRequired
    case inconsistentData(String)
    case noSeatData

    var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            return "页面加载失败：\(message)"
        case .javascriptFailed(let message):
            return "读取页面失败：\(message)"
        case .loginRequired:
            return "需要重新登录"
        case .inconsistentData(let message):
            return "页面数据暂不一致：\(message)"
        case .noSeatData:
            return "没有读取到 SIP 座位数据"
        }
    }
}
