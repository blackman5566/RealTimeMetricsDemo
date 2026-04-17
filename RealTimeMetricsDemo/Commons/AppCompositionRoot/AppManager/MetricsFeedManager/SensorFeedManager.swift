//
//  MetricsFeedManager.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation

/// MetricsFeedManager
/// ViewModel 的資料整合入口（Facade / Orchestrator）
///
/// 職責：
/// - 整合 Sensor（低頻）與 Metric（初始 + 即時更新，高頻）
/// - 對上層提供「單一入口」API，避免 ViewModel 直接碰 repo / store / update manager
public final class MetricsFeedManager {

    // MARK: - Dependencies

    /// 感測器列表載入與排序
    private let sensorManager: SensorManager

    /// 初始指標載入流程
    private let metricManager: MetricManager

    /// 即時指標更新管線
    private let metricUpdateManager: MetricUpdateManager

    /// 指標狀態的單一真相
    private let store: MetricStore

    public init(
        sensorManager: SensorManager,
        metricManager: MetricManager,
        metricUpdateManager: MetricUpdateManager,
        store: MetricStore
    ) {
        self.sensorManager = sensorManager
        self.metricManager = metricManager
        self.metricUpdateManager = metricUpdateManager
        self.store = store
    }
}

// MARK: - Initial Load
extension MetricsFeedManager {
    /// 初始載入：提供 UI 初始化所需資料
    /// - 回傳排序後的 sensors + 初始 metric 快照
    /// - sensors 與 initial metric 可並行載入以縮短等待時間
    public func loadInitial() async throws -> (sensors: [Sensor], metricByID: [SensorID: Metric]) {
        async let sensors = sensorManager.loadSensorsSorted()
        async let metricByID = metricManager.loadInitialMetric()
        return try await (sensors: sensors, metricByID: metricByID)
    }
    
}

// MARK: - Live Updates
extension MetricsFeedManager {
    /// 訂閱「哪些 sensorID 有變更」的事件流
    /// - 開啟 ViewModel 收到 changedIDs 後，再用 `fetchMetricSnapshot` 拉取最新值
    public func observeChangedIDs() -> AsyncStream<[SensorID]> {
        metricUpdateManager.changedIDsStream
    }

    /// 依指定 sensorIDs 取得最新 metric（局部快照）
    /// - 用於收到 changedIDs 後，只更新必要的資料，避免整頁重算
    public func fetchMetricSnapshot(for sensorIDs: [SensorID]) async -> [SensorID: Metric] {
        await store.snapshot(for: sensorIDs)
    }
}


// MARK: - Lifecycle Control
extension MetricsFeedManager {
    /// 畫面離開時停止即時更新
    public func stopUpdates() {
        metricUpdateManager.stop()
    }

    /// 畫面回來時啟動即時更新
    public func startUpdates() {
        metricUpdateManager.start()
    }
}
