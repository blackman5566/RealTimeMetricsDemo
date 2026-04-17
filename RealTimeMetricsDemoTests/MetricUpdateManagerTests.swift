//
//  MetricUpdateManagerTests.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import XCTest
@testable import RealTimeMetricsDemo

/// ManualMetricUpdateSource（測試替身）
///
/// 為什麼需要它？
/// - 真實世界的 MetricUpdateSource 可能是 WebSocket / Timer 推播
/// - 單元測試若依賴真實時間（sleep / interval）會變慢且容易 flaky
///
/// 這個替身允許測試「手動推送 batch」，精準控制事件時機。
///
/// ⚠️ 重要：
/// `MetricUpdateManager.start()` 內部是開一個背景 Task 才去呼叫 `source.makeStream()`。
/// 所以測試若太快呼叫 `send()`，可能發生 continuation 尚未建立（nil），
/// 導致事件被丟失，expectation 超時。
///
/// 因此這裡加入 subscribed expectation：
/// - 一旦 makeStream() 被呼叫並拿到 continuation，就 fulfill
/// - 測試必須先等待 subscribed，再開始 send，才能 100% 穩定。
final class ManualMetricUpdateSource: MetricUpdateSource {
    private var continuation: AsyncStream<[Metric]>.Continuation?
    private let subscribed: XCTestExpectation?

    init(subscribed: XCTestExpectation? = nil) {
        self.subscribed = subscribed
    }

    func makeStream() -> AsyncStream<[Metric]> {
        AsyncStream { cont in
            self.continuation = cont
            self.subscribed?.fulfill()
        }
    }

    /// 手動推送一批 Metric 更新（模擬 WebSocket 收到一個 message）
    func send(_ batch: [Metric]) {
        continuation?.yield(batch)
    }

    /// 手動結束 stream（模擬 WebSocket 關閉）
    func finish() {
        continuation?.finish()
    }
}

/// MetricUpdateManager 的單元測試
///
/// 測試重點：
/// - start() 冪等（避免重複訂閱 / 重複 task）
/// - stop() 確實停止事件輸出（避免背景任務洩漏）
/// - UI flush 模式行為符合預期
final class MetricUpdateManagerTests: XCTestCase {

    /// 驗證：start() 具備冪等性（idempotent）— 多次呼叫不應建立多個背景 Task
    func test_start_isIdempotent_multipleStartDoesNotCreateMultipleTasks() async {
        let subscribed = expectation(description: "Source subscribed")
        let source = ManualMetricUpdateSource(subscribed: subscribed)
        let store = MetricStoreActor()

        let manager = MetricUpdateManager(
            source: source,
            store: store,
            enableUIFlush: false,
            uiFlushInterval: 0.0
        )

        manager.start()
        manager.start()
        manager.start()

        // 等到 background task 真的跑到 makeStream() 並建立 continuation
        await fulfillment(of: [subscribed], timeout: 1.0)

        let stream = manager.changedIDsStream
        let expect = expectation(description: "Receive changedIDs once")

        Task {
            var iterator = stream.makeAsyncIterator()
            let first = await iterator.next()
            XCTAssertEqual(Set(first ?? []), [1], "應只回報一次 changedIDs，避免重複 Task 造成多次通知")
            expect.fulfill()
        }

        // 這時 continuation 一定存在，不會丟事件
        source.send([
            Metric(
                sensorID: 1,
                temperatureCelsius: Decimal(string: "1.70")!,
                humidityPercent: Decimal(string: "3.50")!
            )
        ])

        await fulfillment(of: [expect], timeout: 1.0)
        manager.stop()
    }

    /// 驗證：stop() 會正確取消背景 Task，停止後不應再有事件輸出
    func test_stop_cancelsBackgroundTask_noMoreEventsAfterStop() async {
        let subscribed = expectation(description: "Source subscribed")
        let source = ManualMetricUpdateSource(subscribed: subscribed)
        let store = MetricStoreActor()

        let manager = MetricUpdateManager(
            source: source,
            store: store,
            enableUIFlush: false,
            uiFlushInterval: 0.0
        )

        manager.start()

        // ✅ 先確保訂閱完成，避免第一個事件就丟失
        await fulfillment(of: [subscribed], timeout: 1.0)

        let stream = manager.changedIDsStream
        let gotFirst = expectation(description: "Got first event")
        gotFirst.assertForOverFulfill = true

        // 反向期待：不應收到第二個事件
        let shouldNotGetSecond = expectation(description: "Should NOT get second event")
        shouldNotGetSecond.isInverted = true

        Task {
            var iterator = stream.makeAsyncIterator()

            let first = await iterator.next()
            XCTAssertEqual(Set(first ?? []), [1], "stop 前應能正常收到 changedIDs")
            gotFirst.fulfill()

            // stop 後就算 source 再送，也不該再收到（短時間內）
            let second = await iterator.next()
            if second != nil {
                shouldNotGetSecond.fulfill()
            }
        }

        // 第一次送：應收到
        source.send([
            Metric(
                sensorID: 1,
                temperatureCelsius: Decimal(string: "1.80")!,
                humidityPercent: Decimal(string: "3.40")!
            )
        ])

        await fulfillment(of: [gotFirst], timeout: 1.0)

        // stop：取消背景任務
        manager.stop()

        // stop 後再送：不應再收到
        source.send([
            Metric(
                sensorID: 2,
                temperatureCelsius: Decimal(string: "2.10")!,
                humidityPercent: Decimal(string: "2.90")!
            )
        ])

        // 等一小段時間確認沒有第二次事件（inverted expectation）
        await fulfillment(of: [shouldNotGetSecond], timeout: 0.2)
    }

    /// 驗證：UI flush 模式在 interval = 0 時的行為（等同「每批都 flush」）
    func test_runWithFlush_intervalZero_flushesEveryBatch() async {
        let subscribed = expectation(description: "Source subscribed")
        let source = ManualMetricUpdateSource(subscribed: subscribed)
        let store = MetricStoreActor()

        let manager = MetricUpdateManager(
            source: source,
            store: store,
            enableUIFlush: true,
            uiFlushInterval: 0.0 // 關鍵：每次都 >= 0，等同每批都 flush
        )

        manager.start()

        // ✅ 確保訂閱完成再送資料
        await fulfillment(of: [subscribed], timeout: 1.0)

        let stream = manager.changedIDsStream
        let e1 = expectation(description: "Batch1")
        let e2 = expectation(description: "Batch2")

        Task {
            var it = stream.makeAsyncIterator()

            let first = await it.next()
            XCTAssertEqual(Set(first ?? []), [1, 2], "第一批更新應回報 changedIDs = {1,2}")
            e1.fulfill()

            let second = await it.next()
            XCTAssertEqual(Set(second ?? []), [2, 3], "第二批更新應回報 changedIDs = {2,3}")
            e2.fulfill()
        }

        // 第一批：改 1、2
        source.send([
            Metric(sensorID: 1, temperatureCelsius: Decimal(string: "1.60")!, humidityPercent: Decimal(string: "3.60")!),
            Metric(sensorID: 2, temperatureCelsius: Decimal(string: "1.90")!, humidityPercent: Decimal(string: "3.20")!)
        ])

        // 第二批：改 2、3
        source.send([
            Metric(sensorID: 2, temperatureCelsius: Decimal(string: "2.00")!, humidityPercent: Decimal(string: "3.10")!),
            Metric(sensorID: 3, temperatureCelsius: Decimal(string: "2.20")!, humidityPercent: Decimal(string: "2.80")!)
        ])

        await fulfillment(of: [e1, e2], timeout: 1.0)
        manager.stop()
    }
}
