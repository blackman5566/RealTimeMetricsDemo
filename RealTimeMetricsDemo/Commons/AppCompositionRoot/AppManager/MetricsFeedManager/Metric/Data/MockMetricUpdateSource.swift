//
//  MetricUpdateSource.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation

/// MockMetricUpdateSource：模擬即時推播的指標更新來源（類 WebSocket）
///
/// 職責：
/// - 以固定間隔產生一批 metric 更新資料（batch）
///— - 透過 `AsyncStream<[Metric]>` 持續輸出，供 `MetricUpdateManager` 訂閱
///
/// 使用情境：
/// - 開發階段沒有真 WebSocket 時，用來跑通「即時更新管線」
/// - 壓力/效能測試（調整 interval、maxUpdatesPerTick 觀察 UI 流暢度）
public final class MockMetricUpdateSource: MetricUpdateSource {
    private let interval: TimeInterval
    private let maxUpdatesPerTick: Int

    public init(interval: TimeInterval, maxUpdatesPerTick: Int) {
        self.interval = interval
        self.maxUpdatesPerTick = maxUpdatesPerTick
    }
}

///MARK: 建立更新事件流（每次跟給 一批 Metric）
extension MockMetricUpdateSource {
    ///
    /// 實作方式：
    /// - 內部啟動一個 producer Task
    /// - producer 會在 while 迴圈中：
    ///   1) sleep interval 秒
    ///   2) 隨機產生一批 metric 更新（1...maxUpdatesPerTick）
    ///   3) `yield(batch)` 推送出去
    ///
    /// 結束/釋放：
    /// - 當 consumer 不再訂閱（stream 終止）時，會取消 producerTask，避免背景任務洩漏
    public func makeStream() -> AsyncStream<[Metric]> {
        AsyncStream { continuation in
            /// Producer：持續產生更新批次（模擬推播）
            let producerTask = Task {
                while !Task.isCancelled {
                    // 固定間隔推送一批更新
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                    // 每次隨機產生 1...maxUpdatesPerTick 筆更新
                    let count = Int.random(in: 1...maxUpdatesPerTick)
                    var batch: [Metric] = []
                    batch.reserveCapacity(count)

                    for _ in 0..<count {
                        // 模擬：sensorID 落在 1...100（對應 MockSensorRepository 的 100 筆）
                        let id = Int.random(in: 1...100)

                        // 模擬：隨機環境指標（Decimal 避免浮點誤差累積）
                        let temperatureCelsius = Decimal(Double.random(in: 18.00...32.00))
                        let humidityPercent = Decimal(Double.random(in: 35.00...85.00))
                        batch.append(Metric(sensorID: id, temperatureCelsius: temperatureCelsius, humidityPercent: humidityPercent))
                    }

                    // 推送這批更新
                    continuation.yield(batch)
                }

                // producer 結束時關閉 stream
                continuation.finish()
            }

            // consumer 終止訂閱時，取消 producerTask（避免背景一直跑）
            continuation.onTermination = { _ in
                producerTask.cancel()
            }
        }
    }
}
