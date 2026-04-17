//
//  MetricStoreActorTests.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import XCTest
@testable import RealTimeMetricsDemo

/// MetricStoreActor 的單元測試
///
/// MetricStoreActor 在這個專案裡扮演「指標狀態的單一真相（Single Source of Truth）」：
/// - 所有初始指標 / 即時推播更新，最終都要寫進這裡
/// - UI 更新也應該以這裡的狀態為準
///
/// 因為指標更新是「高頻」場景，MetricStoreActor 的 applyBatch 必須做到：
/// 1) 同一批次內的重複 sensorID 要合併（coalesce），避免白做工
/// 2) 新值與舊值相同時要去除（dedup），避免無意義寫入與 UI 白刷新
/// 3) snapshot(for:) 只回傳目前存在的資料，讓上層做「局部更新」更有效率
///
/// 這些測試的目的：
/// - 不是測 Swift 語法，而是鎖住 store 的「效能與一致性」不變量
/// - 防止未來重構/優化時把 dedup/coalesce 拿掉，導致 UI 卡頓或更新風暴
final class MetricStoreActorTests: XCTestCase {

    /// 驗證：同一批更新內出現多筆相同 sensorID 時，只保留最後一筆（coalesce）
    ///
    /// Why：
    /// - 即時推播可能在同一秒內對同一個感測器更新多次
    /// - 若不合併，會造成重複寫入 store、重複通知 changedIDs，進而增加 UI 更新頻率
    ///
    /// Expected：
    /// - applyBatch 回傳的 changedIDs 應只有 sensorID=1
    /// - store 最終保存的 metric 以「最後一筆」為準（1.90 / 3.20）
    func test_applyBatch_coalescesDuplicateSensorID_keepsLastOne() async {
        let store = MetricStoreActor()

        // 同一批內 sensorID=1 出現兩次，應該以最後一筆為準
        let batch: [Metric] = [
            Metric(sensorID: 1, temperatureCelsius: Decimal(string: "1.80")!, humidityPercent: Decimal(string: "3.10")!),
            Metric(sensorID: 1, temperatureCelsius: Decimal(string: "1.90")!, humidityPercent: Decimal(string: "3.20")!)
        ]

        let changed = await store.applyBatch(batch)
        XCTAssertEqual(Set(changed), [1], "同一批內重複 sensorID 應合併後只回報一次 changedID")

        let snapshot = await store.snapshot(for: [1])
        XCTAssertEqual(
            snapshot[1],
            Metric(sensorID: 1, temperatureCelsius: Decimal(string: "1.90")!, humidityPercent: Decimal(string: "3.20")!),
            "合併後 store 應以最後一筆更新作為最終狀態"
        )
    }

    /// 驗證：當更新值與 store 內既有值相同時，不應回報 changedIDs（dedup no-op updates）
    ///
    /// Why：
    /// - 推播來源可能會重送相同資料（或 rounding 後沒有差異）
    /// - 若不去除無變動更新，會造成 UI 白刷新（row 重新 render）以及無意義的狀態寫入
    ///
    /// Expected：
    /// - 第二次 applyBatch（相同值）應回傳 empty changedIDs
    func test_applyBatch_dedupsNoChange_doesNotReportChangedIDs() async {
        let store = MetricStoreActor()

        // 先寫入一次（建立既有狀態）
        _ = await store.applyBatch([
            Metric(sensorID: 1, temperatureCelsius: Decimal(string: "1.90")!, humidityPercent: Decimal(string: "3.20")!)
        ])

        // 再寫入一模一樣的值：不該算 changed
        let changed = await store.applyBatch([
            Metric(sensorID: 1, temperatureCelsius: Decimal(string: "1.90")!, humidityPercent: Decimal(string: "3.20")!)
        ])

        XCTAssertTrue(changed.isEmpty, "相同值更新應被視為 no-op，不應回報 changedIDs，避免 UI 白刷新")
    }

    /// 驗證：snapshot(for:) 只回傳 store 內已存在的 sensorIDs
    ///
    /// Why：
    /// - 上層在收到 changedIDs 後，會用 snapshot(for:) 做「局部拉取最新 metric」
    /// - snapshot 不應憑空產生資料，且對不存在的 id 應自然忽略，讓呼叫端好處理
    ///
    /// Expected：
    /// - store 只寫入 1、2
    /// - snapshot(for: [1,2,999]) 回傳應只包含 1、2，忽略 999
    func test_snapshot_returnsOnlyExistingIDs() async {
        let store = MetricStoreActor()

        _ = await store.applyBatch([
            Metric(sensorID: 1, temperatureCelsius: Decimal(string: "1.90")!, humidityPercent: Decimal(string: "3.20")!),
            Metric(sensorID: 2, temperatureCelsius: Decimal(string: "2.00")!, humidityPercent: Decimal(string: "3.00")!)
        ])

        let snap = await store.snapshot(for: [1, 2, 999])

        XCTAssertEqual(snap.count, 2, "snapshot 應只回傳 store 內已存在的 sensorIDs")
        XCTAssertNotNil(snap[1], "snapshot 應包含 sensorID=1")
        XCTAssertNotNil(snap[2], "snapshot 應包含 sensorID=2")
        XCTAssertNil(snap[999], "snapshot 不應回傳不存在的 sensorID=999")
    }
}

