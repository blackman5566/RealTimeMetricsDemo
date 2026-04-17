//
//  MetricManagerTests.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import XCTest
@testable import RealTimeMetricsDemo

/// MetricManager 的單元測試
///
/// 測試目的：
/// 驗證「初始指標載入（bootstrap）」是否正確遵守系統架構設計
///
/// 系統設計前提：
/// - MetricStore 是指標狀態的 Single Source of Truth（單一真相）
/// - 所有指標（包含初始化與即時更新）最終都必須寫入 MetricStore
/// - UI / ViewModel 初始化時，**只能使用從 store 讀回來的 snapshot**
///
/// 若未來有人修改 MetricManager，
/// 例如：
/// - 忘記將 repo 回傳的初始指標寫入 store
/// - 直接把 repo 的結果回傳給 UI 使用
///
/// 這個測試可以第一時間阻止這類「破壞系統一致性」的改動
final class MetricManagerTests: XCTestCase {

    /// 驗證初始指標載入的「一致性保證」
    ///
    /// 測試流程說明：
    ///
    /// Given：
    /// - MockMetricRepository：固定回傳 100 筆初始指標（sensorID 1...100）
    /// - 空的 MetricStoreActor：模擬系統啟動時尚未有任何指標狀態
    ///
    /// When：
    /// - 呼叫 MetricManager.loadInitialMetric()
    ///
    /// Then：
    /// 1) 回傳的 snapshot 應包含 100 筆初始指標
    /// 2) MetricStore 內部狀態必須已被寫入相同資料
    /// 3) 回傳給 UI 的 snapshot 必須與 store 內的狀態完全一致
    ///
    /// 這確保：
    /// - UI 初始化資料與系統內實際狀態不會分裂
    /// - 後續即時更新可以無縫接續在同一份狀態之上
    func test_loadInitialMetric_writesToStore_andReturnsStoreSnapshot() async throws {

        // Arrange：準備測試所需的依賴物件
        let repo = MockMetricRepository()
        let store = MetricStoreActor()
        let manager = MetricManager(repo: repo, store: store)

        // Act：執行初始指標載入（bootstrap 流程）
        let snapshot = try await manager.loadInitialMetric()

        // Assert：1) 確認 UI 初始化資料數量正確（Mock 回傳固定 100 筆）
        XCTAssertEqual(snapshot.count, 100, "初始指標 snapshot 應包含 100 筆資料（sensorID 1...100）")
        XCTAssertNotNil(snapshot[1], "snapshot 中應包含 sensorID = 1 的指標")
        XCTAssertNotNil(snapshot[100], "snapshot 中應包含 sensorID = 100 的指標")

        // Assert：2) 驗證 MetricStore 真的已被寫入（而非只回傳 repo 的值）
        // 隨機抽取幾個 sensorID，從 store 取回 snapshot 與回傳結果比對
        let storeSnap = await store.snapshot(for: [1, 50, 100])

        XCTAssertEqual(storeSnap[1], snapshot[1], "回傳給 UI 的 snapshot 必須與 store 狀態一致（sensorID = 1）")
        XCTAssertEqual(storeSnap[50], snapshot[50], "回傳給 UI 的 snapshot 必須與 store 狀態一致（sensorID = 50）")
        XCTAssertEqual(storeSnap[100], snapshot[100], "回傳給 UI 的 snapshot 必須與 store 狀態一致（sensorID = 100）")
    }
}

