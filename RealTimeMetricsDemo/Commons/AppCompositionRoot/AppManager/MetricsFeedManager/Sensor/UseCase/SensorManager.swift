//
//  SensorManager.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation

/// SensorManager：負責「感測器資料」的載入與基本處理（屬於低頻資料）
///
/// 設計目的：
/// 1. 把「資料從哪裡來」（Repository）跟「資料要怎麼整理」（排序規則）分開
/// 2. 上層（ViewModel/UI）不用知道資料來源是 Mock / API / 檔案 / DB
/// 3. 未來若排序規則改變，只需要改這裡，不會影響整個 UI
public final class SensorManager {
    /// Repository：提供感測器資料的來源（可能是 Mock / API / DB / File 等）
    /// 透過 protocol 注入，方便替換與測試
    private let repo: SensorRepository

    /// 初始化時注入 repo（依賴注入 DI）
    /// 好處：測試時可以丟 FakeRepository 進來，避免打網路/讀檔造成測試不穩
    public init(repo: SensorRepository) {
        self.repo = repo
    }
}

// MARK: - Public API
extension SensorManager {
    /// 載入感測器資料，並依 updatedAt 做升序排序（時間越近排越上面）
    ///
    /// - async：資料來源可能是網路/檔案，屬於非同步工作
    /// - throws：資料來源可能失敗（例如網路錯誤、檔案不存在、解析失敗）
    ///
    /// 回傳：
    /// - 已排序的感測器列表，供上層直接顯示
    public func loadSensorsSorted() async throws -> [Sensor] {
        /// 1) 向 Repository 取回原始資料（不假設資料已排序）
        let sensors = try await repo.fetchSensors()
        
        /// 2) 依 updatedAt 升序排序：越早更新的越前面
        /// 題目要求：最早更新的在上方（升序）
        return sensors.sorted { $0.updatedAt < $1.updatedAt }
    }
}
