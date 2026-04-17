//
//  RealTimeMetricsDemoApp.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import SwiftUI

@main
struct DemoTabApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}

struct RootTabView: View {
    private enum AppTab {
        case home
        case sensor
    }

    @State private var selectedTab: AppTab = .home
    @State private var sensorViewModel =
    SensorListViewModel(
        feed: AppCompositionRoot.shared.metricsFeedManager
    )

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeTab()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(AppTab.home)

            NavigationStack {
                SensorListView(viewModel: sensorViewModel)
            }
            .tabItem {
                Label("Sensor", systemImage: "list.bullet")
            }
            .tag(AppTab.sensor)
        }
        .onChange(of: selectedTab) { _, newTab in
            switch newTab {
            case .home:
                sensorViewModel.onDisappear()
            case .sensor:
                sensorViewModel.onAppear()
            }
        }
    }
}

struct HomeTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Home Tab")
            Text("切到 Sensor tab 會觸發 onAppear")
        }
        .padding()
        .navigationTitle("Home")
    }
}
