//
//  MetricStoreActor.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation

/// MetricStoreActor：指標狀態儲存（Store / 單一真相）
///
/// 你可以把它想成：
/// - 一個 thread-safe 的 Dictionary（key = sensorID, value = 最新 metric）
/// - 系統內所有人都只讀/寫這裡，避免狀態分散造成不一致
///
/// 主要目的：
/// 1) 保存每個感測器最新的 metric（UI 要顯示的就是這份狀態）
/// 2) 高頻更新時，避免無意義的寫入與 UI 刷新
/// 3) 回傳 changedIDs，讓上層只更新有變動的 row（局部更新）
public actor MetricStoreActor: MetricStore {

    /// 最新指標快取：sensorID → Metric
    private var metricByID: [SensorID: Metric] = [:]

    public init() {}
}

// MARK: - Read
extension MetricStoreActor {
    /// 取得單筆 metric
    /// - 若該 sensorID 尚未有資料，回傳 nil
    public func get(_ id: SensorID) async -> Metric? {
        metricByID[id]
    }

    /// 取得指定 sensorIDs 的 metric 快照（局部讀取）
    ///
    /// 使用情境：
    /// - UI 初始化：拿一批 ids 對應的 metric
    /// - 即時更新：收到 changedIDs 後，只取這些 ids 的最新值
    public func snapshot(for ids: [SensorID]) async -> [SensorID: Metric] {
        var result: [SensorID: Metric] = [:]
        result.reserveCapacity(ids.count)

        for id in ids {
            if let metric = metricByID[id] {
                result[id] = metric
            }
        }
        return result
    }
}

// MARK: - Write
extension MetricStoreActor {
    /// 套用一批 metric 更新，回傳「真的有變動」的 sensorIDs
    ///
    /// 題目特性：
    /// - 每秒可能來多筆更新
    /// - 同一秒內可能同一個感測器被更新多次
    ///
    /// 這個方法做兩層處理：
    /// 1) 合併同一批內的重複更新：同 sensorID 只保留最後一筆（避免白做工）
    /// 2) 去除無變動更新：新值跟舊值一樣就不寫入、也不通知（避免 UI 白刷新）
    public func applyBatch(_ updates: [Metric]) async -> [SensorID] {
        let incomingCount = updates.count

        // 1) 合併：同 sensorID 在同一批只取最後一筆
        var latestByID: [SensorID: Metric] = [:]
        latestByID.reserveCapacity(incomingCount)
        for u in updates {
            latestByID[u.sensorID] = u
        }
        let coalescedCount = latestByID.count

        // 2) 去除無變動：只有真的不同才寫入，並回報 changedIDs
        var changedIDs: [SensorID] = []
        changedIDs.reserveCapacity(coalescedCount)

        var dedupCount = 0

        for (id, newMetric) in latestByID {
            let oldMetric = metricByID[id]
            if oldMetric != newMetric {
                metricByID[id] = newMetric
                changedIDs.append(id)
            } else {
                dedupCount += 1
            }
        }

        // Debug：觀察這批更新有多少被合併/去除，實際需要更新 UI 的有多少
        print("【MetricStore】incoming=\(incomingCount), coalesced=\(coalescedCount), changed=\(changedIDs.count), dedup=\(dedupCount)")

        return changedIDs
    }
}
