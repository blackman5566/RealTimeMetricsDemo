//
//  AppCore.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation

public typealias SensorID = Int

// MARK: - Repository（資料來源）
/// 負責取得感測器列表（初始資料）
public protocol SensorRepository {
    func fetchSensors() async throws -> [Sensor]
}

/// 負責取得初始指標（初始資料）
public protocol MetricRepository {
    func fetchInitialMetric() async throws -> [Metric]
}

// MARK: - Update Source（推播來源）
/// 模擬 WebSocket：每次吐一批（一次多筆）指標更新
public protocol MetricUpdateSource {
    /// 每次事件代表「一批」更新（題目：每秒最多 10 筆）
    func makeStream() -> AsyncStream<[Metric]>
}

// MARK: - Store（快取/單一真相）
/// 指標快取的單一真相來源（Single Source of Truth）
/// - 需要 thread-safe：用 actor 實作
public protocol MetricStore: Sendable {
    /// 讀取單筆指標
    func get(_ id: SensorID) async -> Metric?

    /// 讀取多筆快照（常用於畫面初始化）
    func snapshot(for ids: [SensorID]) async -> [SensorID: Metric]

    /// 批次套用更新（一次多筆）
    /// - 回傳「真正有變動」的 sensorIDs（讓 UI 只更新必要的 row）
    func applyBatch(_ updates: [Metric]) async -> [SensorID]
}
