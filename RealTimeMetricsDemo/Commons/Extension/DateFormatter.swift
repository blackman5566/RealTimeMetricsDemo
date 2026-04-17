//
//  DateFormatter.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation

extension DateFormatter {
    static let yyyyMMddHHmm: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd HH:mm"
        df.locale = Locale(identifier: "zh_TW")
        return df
    }()
}
