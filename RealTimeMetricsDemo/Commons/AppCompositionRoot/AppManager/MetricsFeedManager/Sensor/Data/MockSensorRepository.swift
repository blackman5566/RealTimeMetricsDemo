//
//  SensorRepository.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation

/// MockSensorRepository：提供可預期的假感測器資料（100 筆）
/// - `updatedAt` 以 2 分鐘遞增，方便驗證「依最後更新時間升序排序」的結果
public final class MockSensorRepository: SensorRepository {
    public init() {}

    public func fetchSensors() async throws -> [Sensor] {
        let now = Date()
        return (0..<100).map { idx in
            Sensor(
                sensorID: idx + 1,
                sensorName: "Sensor \(idx + 1)",
                sensorZone: "Zone \((idx % 5) + 1)",
                updatedAt: Calendar.current.date(byAdding: .minute, value: idx * 2, to: now) ?? now
            )
        }
    }
}
