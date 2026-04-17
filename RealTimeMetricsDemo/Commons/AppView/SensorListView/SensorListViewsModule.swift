//
//  SensorListViewsModule.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//
import SwiftUI

enum SensorListViewsModule {

    /// 建立安全設定頁面（已完成依賴注入）
    ///
    /// - Returns: SensorListView（內含已配置好的 SensorListViewModel）
    @MainActor static func view() -> some View {

        /// 在 module 層完成依賴注入：
        /// MetricsFeedManager：資料整合層（Facade / Orchestrator）
        ///
        /// 這一層的目的：
        /// - 把「感測器列表 Sensor」+「初始指標 Metric」+「即時指標更新」統一整理成 ViewModel 好用的 API
        /// - ViewModel 不需要知道資料來源細節（repo / store / update stream），只要跟 FeedManager 拿資料即可
        ///
        let viewModel = SensorListViewModel(feed: AppCompositionRoot.shared.metricsFeedManager)

        /// 回傳真正的 UI（View 不用關心依賴怎麼來）
        return SensorListView(viewModel: viewModel)
    }
}
