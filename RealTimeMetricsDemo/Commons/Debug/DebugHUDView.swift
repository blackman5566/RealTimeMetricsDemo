//
//  DebugHUDView.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/4/17.
//

import SwiftUI

public struct DebugHUDView: View {
    let viewModel: SensorListViewModel

    public init(viewModel: SensorListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("更新批次（tick）：\(viewModel.updateTick)")
            Text("本次變更 Row 數：\(viewModel.lastChangedCount)")
            Text("累積變更 Row 數：\(viewModel.totalRowUpdates)")
        }
        .font(.caption)
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .fixedSize()
    }
}
