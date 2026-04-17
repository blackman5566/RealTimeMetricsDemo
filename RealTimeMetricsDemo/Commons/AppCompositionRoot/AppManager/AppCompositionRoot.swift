//
//  AppManager.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation

/// Composition Root：
/// 系統中唯一負責「組裝所有依賴物件」的地方
/// - 其他模組一律透過注入取得依賴
/// - 不允許在任意地方自行 new，才能維持清楚的系統邊界
public final class AppCompositionRoot {
    public static let shared = AppCompositionRoot()
    public let env: AppEnvironment

    // MARK: - 資料來源（Data Providers）
    /// 感測器資料來源（API / Mock）
    public let sensorRepository: SensorRepository

    /// 初始指標資料來源（API / Mock）
    public let metricRepository: MetricRepository

    /// 即時指標更新來源（WebSocket / Timer / Mock）
    public let metricUpdateSource: MetricUpdateSource

    // MARK: - 狀態儲存（Single Source of Truth）
    /// 指標狀態的唯一資料來源
    /// - 所有初始載入與即時更新最終都寫入這裡
    public let metricStore: MetricStore

    // MARK: - Domain Managers（Use Case / 協調者）
    /// 負責感測器資料的載入與基本處理
    public let sensorManager: SensorManager

    /// 負責「初始指標」的載入流程（bootstrap）
    public let metricManager: MetricManager

    /// 負責「即時指標更新」的啟動、停止與生命周期管理
    public let metricUpdateManager: MetricUpdateManager

    // MARK: - ViewModel 對外 Facade
    /// 提供給 ViewModel 使用的高階入口
    /// - ViewModel 不需要知道 repo / store / update source 的存在
    public let metricsFeedManager: MetricsFeedManager

    public init() {
        // 0) 環境設定
        self.env = .init()

        // 1) 資料來源（目前使用 Mock，未來切換真實 API / WS 只需改這裡）
        self.sensorRepository = MockSensorRepository()
        self.metricRepository  = MockMetricRepository()
        self.metricUpdateSource = MockMetricUpdateSource(
            interval: env.updatesPerSecond,
            maxUpdatesPerTick: env.maxUpdatesPerTick
        )
        

        // 2) 狀態儲存（指標的單一資料來源）
        self.metricStore = MetricStoreActor()

        // 3) Use Cases / Domain Managers
        self.sensorManager = SensorManager(repo: sensorRepository)

        /// 初始指標載入流程：
        /// - 從 repository 取得外部指標資料
        /// - 寫入 store 成為系統內的 canonical state
        /// - 回傳 snapshot 供 UI 初始化使用
        self.metricManager = MetricManager(
            repo: metricRepository,
            store: metricStore
        )

        /// 即時指標更新流程：
        /// - 由 update source 產生更新事件
        /// - 寫入 store
        /// - 視設定決定是否進行 UI flush
        self.metricUpdateManager = MetricUpdateManager(
            source: metricUpdateSource,
            store: metricStore,
            enableUIFlush: env.enableUIFlush,
            uiFlushInterval: env.uiFlushInterval
        )

        // 4) ViewModel 使用的整合入口
        /// 將以下能力整合成 ViewModel 好用的 API：
        /// - 感測器列表資料
        /// - 初始指標載入
        /// - 即時指標更新
        /// ViewModel 不需要理解任何底層資料來源與同步細節
        self.metricsFeedManager = MetricsFeedManager(
            sensorManager: sensorManager,
            metricManager: metricManager,
            metricUpdateManager: metricUpdateManager,
            store: metricStore
        )
    }
}
