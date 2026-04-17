//
//  MetricUpdateManager.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation
/// MetricUpdateManager：即時更新管線（source → store → changedIDs）
///
/// - start/stop 控制背景任務生命週期
/// - 可選 UI flush：將短時間內多次變更合併，降低 UI 更新頻率
/// MetricUpdateManager 透過 AsyncStream 對外輸出 changedIDs；每次套用更新後若有變動，會 yield([SensorID]) 通知上層進行局部更新。
/// MARK: - Lifecycle
public final class MetricUpdateManager {
    /// 對外輸出：哪些 sensorID 有變動
    public var changedIDsStream: AsyncStream<[SensorID]> { changedIDs }

    // MARK: - Dependencies
    private let source: MetricUpdateSource
    private let store: MetricStore

    // MARK: - Stream plumbing
    private var changedIDs: AsyncStream<[SensorID]>
    private var continuation: AsyncStream<[SensorID]>.Continuation?

    // MARK: - Config
    private let enableUIFlush: Bool
    private let uiFlushInterval: TimeInterval

    private var task: Task<Void, Never>?

    public init(
        source: MetricUpdateSource,
        store: MetricStore,
        enableUIFlush: Bool,
        uiFlushInterval: TimeInterval
    ) {
        // 保存依賴與設定（source / store / UI flush 參數）
        self.source = source
        self.store = store
        self.enableUIFlush = enableUIFlush
        self.uiFlushInterval = uiFlushInterval

        // 建立對外的 changedIDs 事件流，並保留 continuation 供內部隨時 yield
        var cont: AsyncStream<[SensorID]>.Continuation?
        self.changedIDs = AsyncStream { c in cont = c }
        self.continuation = cont
    }
}

// MARK: - Public API
public extension MetricUpdateManager {

    /// 啟動即時指標更新
    ///
    /// 行為說明：
    /// - 只允許同一時間存在一個背景更新任務（避免重複訂閱 source）
    /// - 背景 Task 會持續消費 update source 的 AsyncStream
    /// - 依設定決定是否啟用 UI flush（節流合併 UI 更新）
    func start() {
        // 防止重複呼叫 start() 時，建立多個背景任務
        guard task == nil else { return }
        
        // 每輪 start 開一條新的 output stream，避免沿用已終止的 stream
        buildChangedIDsStream()
        
        // 建立並保存背景 Task（避免 fire-and-forget）
        task = Task { [weak self] in
            // 若 manager 已被釋放，直接結束任務
            guard let self else { return }

            // 向 update source 建立資料流（例如 WebSocket / Mock）
            let stream = self.source.makeStream()

            // 依設定選擇執行模式：
            // - runDirect：每批更新都立即通知 UI
            // - runWithFlush：合併短時間內的多次更新，降低 UI 更新頻率
            if self.enableUIFlush {
                await self.runWithFlush(stream: stream)
            } else {
                await self.runDirect(stream: stream)
            }
        }
    }


    /// 停止即時更新（取消背景 task，並允許下次重新 start）
    func stop() {
        task?.cancel()
        task = nil
        
        //結束本輪 stream，讓 consumer 正常收尾
        continuation?.finish()
        continuation = nil
    }
    
    func buildChangedIDsStream() {
        var cont: AsyncStream<[SensorID]>.Continuation?
        self.changedIDs = AsyncStream { c in
            c.onTermination = { t in
                print("🔌 changedIDsStream terminated: \(t)")
            }
            cont = c
        }
        self.continuation = cont
    }
}

// MARK: - Internal runners
extension MetricUpdateManager {
    
    /// 不做節流：每批更新都立即 apply 並 yield changedIDs
    func runDirect(stream: AsyncStream<[Metric]>) async {
        for await batch in stream {
            if Task.isCancelled { break }

            let changed = await store.applyBatch(batch)
            if !changed.isEmpty {
                continuation?.yield(changed)
            }
        }
    }

    /// 節流模式：累積一段時間內的 changedIDs，定期一次吐出
    func runWithFlush(stream: AsyncStream<[Metric]>) async {
        var pending = Set<SensorID>()
        var lastFlush = Date()

        for await batch in stream {
            if Task.isCancelled { break }
            let changed = await store.applyBatch(batch)
            for id in changed { pending.insert(id) }

            let now = Date()
            if now.timeIntervalSince(lastFlush) >= uiFlushInterval {
                if !pending.isEmpty {
                    continuation?.yield(Array(pending))
                    pending.removeAll()
                }
                lastFlush = now
            }
        }

        // stream 結束或 task 被取消前，把剩下 pending 一次吐出去
        if !pending.isEmpty {
            continuation?.yield(Array(pending))
        }
    }
}

