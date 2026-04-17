//
//  MockMetricRepository.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation

/// Mock：回傳 100 筆初始指標
public final class MockMetricRepository: MetricRepository {
    public init() {}

    public func fetchInitialMetric() async throws -> [Metric] {
        return (0..<100).map { idx in
            let temperatureCelsius = Decimal(Double.random(in: 18.00...32.00))
            let humidityPercent = Decimal(Double.random(in: 35.00...85.00))
            return Metric(
                sensorID: idx + 1,
                temperatureCelsius: temperatureCelsius,
                humidityPercent: humidityPercent)
        }
    }
}
