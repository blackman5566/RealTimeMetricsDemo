//
//  FPSOverlayView.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import SwiftUI

/// FPSOverlayView：右上角顯示 FPS
public struct FPSOverlayView: View {

    /// 用 @Bindable 讀取 @Observable 的變化（iOS 17+）
    @Bindable var counter: FPSCounter

    public init(counter: FPSCounter) {
        self.counter = counter
    }

    public var body: some View {
        Text("FPS: \(counter.fps)")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.6))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel("FPS \(counter.fps)")
    }
}
