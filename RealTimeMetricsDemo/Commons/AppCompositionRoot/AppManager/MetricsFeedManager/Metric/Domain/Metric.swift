//
//  Metric.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation

public struct Metric: Codable, Sendable, Equatable {
    public let sensorID: SensorID

    public let temperatureCelsius: Decimal
    public let humidityPercent: Decimal

    public init(sensorID: SensorID, temperatureCelsius: Decimal, humidityPercent: Decimal) {
        self.sensorID = sensorID
        self.temperatureCelsius = temperatureCelsius
        self.humidityPercent = humidityPercent
    }
}
