//
//  Decimal.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//
import SwiftUI

extension Decimal {
    func format(_ digits: Int = 2) -> String {
        let nf = NumberFormatter()
        nf.minimumFractionDigits = digits
        nf.maximumFractionDigits = digits
        return nf.string(from: self as NSDecimalNumber) ?? "-"
    }
}
