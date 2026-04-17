//
//  MetricManager.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation

/// MetricManager
/// 負責「初始指標」載入流程（bootstrap）
///
/// 職責：
/// - 從 MetricRepository 取得初始指標資料
/// - 寫入 MetricStore 作為系統內的單一真相（canonical state）
/// - 回傳 snapshot 供 UI 初始化使用（確保與 store 狀態一致）
public final class MetricManager {
    private let repo: MetricRepository
    private let store: MetricStore

    public init(repo: MetricRepository, store: MetricStore) {
        self.repo = repo
        self.store = store
    }

    /// 載入初始指標並寫入 store，回傳 `[SensorID: Metric]` 快照
    ///
    /// 設計原因：
    /// - UI 不直接使用 repo 回傳值，而是從 store 取得 snapshot
    /// - 確保 UI 拿到的是「當下系統內的最新一致狀態」
    public func loadInitialMetric() async throws -> [SensorID: Metric] {
        // 1) 取得外部初始指標資料
        let metric = try await repo.fetchInitialMetric()

        // 2) 寫入 store（單一真相）
        _ = await store.applyBatch(metric)

        // 3) 從 store 取回 snapshot（供 UI 初始化）
        let ids = metric.map { $0.sensorID }
        return await store.snapshot(for: ids)
    }
}

