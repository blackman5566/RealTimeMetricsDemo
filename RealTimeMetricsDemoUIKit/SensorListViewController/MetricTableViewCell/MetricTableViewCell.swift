//
//  MetricTableViewCell.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/4/17.
//

import UIKit

final class MetricTableViewCell: UITableViewCell {
    static let reuseID = "MetricCell"

    private let nameLabel = UILabel()
    private let metricLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        metricLabel.font = .systemFont(ofSize: 14, weight: .regular)
        metricLabel.textColor = .secondaryLabel
        metricLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [nameLabel, metricLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    func configure(sensor: Sensor, metric: Metric?) {
        nameLabel.text = sensor.sensorName
        if let m = metric {
            metricLabel.text = "\(m.temperatureCelsius.format())°C  \(m.humidityPercent.format())%"
        } else {
            metricLabel.text = "--"
        }
    }
}
