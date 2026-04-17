//
//  SensorRowView.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import SwiftUI

public struct SensorRowView: View {
    let sensor: Sensor
    let metric: Metric?

    public init(sensor: Sensor, metric: Metric?) {
        self.sensor = sensor
        self.metric = metric
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sensor.sensorName)
                .font(.headline)
            Text(sensor.sensorZone)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(DateFormatter.yyyyMMddHHmm.string(from: sensor.updatedAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let metric {
                HStack {
                    Text("Temp \(metric.temperatureCelsius.format())°C")
                    Text("Humidity \(metric.humidityPercent.format())%")
                }
                .font(.subheadline)
            } else {
                Text("Metric loading...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
