//
//  SensorListView.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import SwiftUI

public struct SensorListView: View {
    @Bindable private var viewModel: SensorListViewModel
    @State private var fpsCounter = FPSCounter()

    public init(viewModel: SensorListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {

        ZStack(alignment: .topLeading) {
            List {
                ForEach(viewModel.sensors, id: \.sensorID) { sensor in
                    SensorRowView(
                        sensor: sensor,
                        metric: viewModel.metricByID[sensor.sensorID]
                    )
                }
            }
            DebugHUDView(viewModel: viewModel)
                .padding(10)
        }
        .navigationTitle("Sensors")
        .onAppear {
            viewModel.onAppear()
            
            //觀看 fps 小工具
            fpsCounter.start()
        }
        .onDisappear {
            viewModel.onDisappear()
            
            //觀看 fps 小工具
            fpsCounter.stop()
        }
        .overlay(alignment: .topTrailing) {
            FPSOverlayView(counter: fpsCounter)
                .padding()
        }
    }
}
