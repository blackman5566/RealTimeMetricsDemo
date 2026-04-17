//
//  SensorListViewModel.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation
import Observation
import Combine

@MainActor
@Observable
public final class SensorListViewModel {

    // Debug 指標：證明「局部 row 更新」，不是整頁重算/重刷
    public private(set) var updateTick: Int = 0
    public private(set) var lastChangedCount: Int = 0
    public private(set) var totalRowUpdates: Int = 0

    // MARK: - UI State
    public var sensors: [Sensor] = []
    public var metricByID: [SensorID: Metric] = [:]

    // MARK: - Dependencies
    private let feed: MetricsFeedManager

    // MARK: - Lifecycle Control
    private var observingTask: Task<Void, Never>?

    // UIKit 綁定用：初始載入完成（重建 diffable snapshot）
    public let initialReload = PassthroughSubject<Void, Never>()

    // UIKit 綁定用：局部更新（給 changedIDs 由 VC reconfigure diffable items）
    public let partialReload = PassthroughSubject<[SensorID], Never>()
    
    public init(feed: MetricsFeedManager) {
        self.feed = feed
    }

    // MARK: - View Lifecycle

    public func onAppear() {
        print("呼叫 onAppear")
        startObservingIfNeeded()
    }

    public func onDisappear() {
        print("呼叫 onDisappear")
        stopObserving()
    }
}

// MARK: - Observing (Subscription)
private extension SensorListViewModel {

    func startObservingIfNeeded() {
        // 防呆：避免重複訂閱，也避免 tab selection + onAppear 連續觸發時重開 stream
        guard observingTask == nil else { return }

        // 啟動推播更新管線（source → store → changedIDs）
        feed.startUpdates()

        observingTask = Task { [weak self] in
            guard let self else { return }
            await self.runInitialLoadThenListen()
        }
    }

    func stopObserving() {
        observingTask?.cancel()
        observingTask = nil

        // 停止繼續要資料
        feed.stopUpdates()
    }

    /// 先做快取恢復 + 初始載入，再進入「持續監聽」迴圈
    func runInitialLoadThenListen() async {
        do {
            await restoreCachedMetricIfNeeded()
            try await loadInitialData()
            await listenMetricChanges()
        } catch {
            print("Load error: \(error)")
        }
    }

    /// MARK: 0) 快取恢復：先用 store 快照補齊目前畫面（秒回 UI）
    func restoreCachedMetricIfNeeded() async {
        guard !sensors.isEmpty else { return }
        let ids = sensors.map(\.sensorID)
        let cached = await feed.fetchMetricSnapshot(for: ids)
        metricByID.merge(cached) { _, new in new }
    }

    /// MARK: 1) 開始載入最新資料
    func loadInitialData() async throws {
        let initial = try await feed.loadInitial()
        sensors = initial.sensors
        metricByID = initial.metricByID
        
        //uikit用
        initialReload.send(())
    }

    /// MARK: 2) 訂閱增量更新（持續性）
    /// 這是一條「事件流監聽」：只要 updates 還在跑，它就會持續收到 changedIDs
    func listenMetricChanges() async {
        for await changedIDs in feed.observeChangedIDs() {
            await onMetricChanged(changedIDs)
        }
    }

    /// 收到「哪些 sensorID 的 metric 真的變了」之後的處理流程
    func onMetricChanged(_ changedIDs: [SensorID]) async {
        let snapshot = await feed.fetchMetricSnapshot(for: changedIDs)
        applyMetricSnapshot(snapshot)
        recordPartialUpdate(changedIDs: changedIDs)
        
        //uikit用
        partialReload.send(changedIDs)
    }

    /// 只更新變動的那幾筆（局部更新）
    func applyMetricSnapshot(_ snapshot: [SensorID: Metric]) {
        for (id, metric) in snapshot {
            metricByID[id] = metric
        }
    }
}

// MARK: - UI Partial Update Metrics
private extension SensorListViewModel {
    func recordPartialUpdate(changedIDs: [SensorID]) {
        updateTick += 1
        lastChangedCount = changedIDs.count
        totalRowUpdates += changedIDs.count
    }
}
