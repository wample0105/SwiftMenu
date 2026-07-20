import AppKit
import FinderSync
import Foundation

@main
@MainActor
struct MenuConstructionBenchmark {
    static func main() {
        let coldStart = DispatchTime.now().uptimeNanoseconds
        let finderSync = FinderSync()
        _ = finderSync.menu(for: .contextualMenuForContainer)
        let coldPath = milliseconds(DispatchTime.now().uptimeNanoseconds - coldStart)
        let warmupIterations = 100
        let measuredIterations = 1_000

        for _ in 0..<warmupIterations {
            _ = finderSync.menu(for: .contextualMenuForContainer)
        }

        var durations = [UInt64]()
        durations.reserveCapacity(measuredIterations)

        for _ in 0..<measuredIterations {
            let start = DispatchTime.now().uptimeNanoseconds
            _ = finderSync.menu(for: .contextualMenuForContainer)
            durations.append(DispatchTime.now().uptimeNanoseconds - start)
        }

        durations.sort()
        let p50 = milliseconds(durations[measuredIterations / 2])
        let p95 = milliseconds(durations[Int(Double(measuredIterations) * 0.95)])
        let maximum = milliseconds(durations[measuredIterations - 1])

        print(String(format: "扩展初始化 + 首次菜单：%.3f ms", coldPath))
        print(String(format: "菜单构造基准：p50 %.3f ms，p95 %.3f ms，最大 %.3f ms（%d 次）", p50, p95, maximum, measuredIterations))

        guard coldPath < 100, p95 < 16, maximum < 50 else {
            fputs("❌ 菜单构造延迟超过生产验收阈值。\n", stderr)
            Foundation.exit(1)
        }
        print("✅ 菜单构造延迟通过生产阈值。")
    }

    private static func milliseconds(_ nanoseconds: UInt64) -> Double {
        Double(nanoseconds) / 1_000_000
    }
}
