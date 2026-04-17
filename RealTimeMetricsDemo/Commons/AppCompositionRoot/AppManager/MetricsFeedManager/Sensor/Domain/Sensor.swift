//
//  Sensor.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation

/// Sensor：即時監控中的資料來源
/// - 用於列表顯示、排序（updatedAt）、以及作為 metric 的關聯主鍵（sensorID）
public struct Sensor: Identifiable, Codable, Sendable, Equatable {

    /// 感測器唯一識別（強型別 ID，避免把一般 Int 亂傳）
    public let sensorID: SensorID

    /// 感測器名稱
    public let sensorName: String

    /// 所屬區域
    public let sensorZone: String

    /// 最後更新時間
    public let updatedAt: Date

    /// SwiftUI `Identifiable` 對應的 id
    public var id: SensorID { sensorID }

    public init(sensorID: SensorID, sensorName: String, sensorZone: String, updatedAt: Date) {
        self.sensorID = sensorID
        self.sensorName = sensorName
        self.sensorZone = sensorZone
        self.updatedAt = updatedAt
    }
}
