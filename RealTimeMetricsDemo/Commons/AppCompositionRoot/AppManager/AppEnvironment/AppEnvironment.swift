//
//  AppEnvironment.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation

/// AppEnvironment
/// 集中管理即時指標系統中「可調整的環境參數」
///
/// 目的：
/// - 將更新頻率、單次更新量、UI 節流等效能相關設定集中管理
/// - 方便在不同環境（Mock / 測試 / 實際運行）進行調校與壓力測試
public struct AppEnvironment: Sendable {

    /// 指標更新推播間隔（秒）
    /// - 例如 1.0 表示每 1 秒產生一次更新
    public var updatesPerSecond: TimeInterval

    /// 每次更新推播的最大指標筆數
    /// - 用於模擬高頻、大量資料更新的情境
    public var maxUpdatesPerTick: Int

    /// 是否啟用 UI 節流機制
    /// - 開啟後可有效降低 UI 更新頻率，提升畫面流暢度
    /// - 開啟後會去參考 uiFlushInterval 時間
    public var enableUIFlush: Bool
    
    /// UI 通知的節流間隔（秒）
    /// - 將多次指標變更合併為較少次的 UI 更新
    /// - 用於避免高頻更新導致畫面卡頓
    public var uiFlushInterval: TimeInterval

    public init(
        updatesPerSecond: TimeInterval = 1,
        maxUpdatesPerTick: Int = 30,
        uiFlushInterval: TimeInterval = 1,
        enableUIFlush: Bool = false
    ) {
        self.updatesPerSecond = updatesPerSecond
        self.maxUpdatesPerTick = maxUpdatesPerTick
        self.uiFlushInterval = uiFlushInterval
        self.enableUIFlush = enableUIFlush
    }
}

