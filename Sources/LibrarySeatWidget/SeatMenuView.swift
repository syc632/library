import SwiftUI

struct SeatMenuView: View {
    @EnvironmentObject private var monitor: SeatMonitor

    var body: some View {
        Group {
            Text("SIP Campus")
                .font(.headline)

            if let snapshot = monitor.snapshot {
                Text("剩余 \(snapshot.totalFree) / \(snapshot.totalSeats)")
                    .monospacedDigit()
                Text("上次更新 \(monitor.lastUpdateText)")

                Divider()

                ForEach(snapshot.floors) { floor in
                    Text("\(floor.name)  Free \(floor.free) / Total \(floor.total)")
                        .monospacedDigit()
                }
            } else {
                Text("等待登录或刷新")
                Text("上次更新 \(monitor.lastUpdateText)")
            }

            if monitor.isRefreshing {
                Divider()
                Text("正在刷新...")
            }

            if let error = monitor.lastError {
                Divider()
                Text(error)
            }

            Divider()

            Button("手动刷新") {
                monitor.refresh()
            }
            .disabled(monitor.isRefreshing)

            Button("重新登录") {
                monitor.showLogin()
            }

            Divider()

            Button("退出") {
                monitor.quit()
            }
        }
    }
}
