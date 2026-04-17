# RealTimeMetricsDemo

RealTimeMetricsDemo 是一個 iOS 系統設計展示專案，用來模擬高頻即時資料更新的情境。

這個專案重點不在視覺設計，而在工程執行品質：非同步事件流、thread-safe 的單一狀態來源、row-level UI 更新、依賴注入，以及用單元測試鎖住核心不變量。

更完整的系統設計說明請看 [`docs/SYSTEM_DESIGN.md`](docs/SYSTEM_DESIGN.md)。

<p align="center">
  <img 
    src="https://github.com/blackman5566/RealTimeMetricsDemo/blob/master/docs/demo.gif" 
    alt="Demo" 
    width="320"
  />
</p>

## 目前版本

### v1.0.0 - SwiftUI

- SwiftUI app shell，使用 `@Observable` / `@Bindable` 管理 ViewModel 狀態。
- 使用 `AsyncStream` 建立 mock update source，模擬 WebSocket 風格的即時資料流。
- 使用 `MetricStoreActor` 作為最新 sensor metrics 的 single source of truth。
- batch coalescing 與 no-op deduplication，降低不必要的 UI 更新。
- 透過 `changedIDs` 建立從 store 到 UI 的局部更新流程。
- tab-aware lifecycle control，離開 Sensor tab 時停止即時更新。
- 使用 composition root 管理 mock repositories 與 update sources 的替換。
- 單元測試覆蓋 store、初始載入與 update pipeline 行為。

### v1.1.0 - UIKit

- 獨立的 `RealTimeMetricsDemoUIKit` app target 與 scheme。
- UIKit table view presentation 共用同一套 domain、store 與 update pipeline。
- 使用 `UITableViewDiffableDataSource` 管理 table view rendering。
- 使用 `NSDiffableDataSourceSnapshot.reconfigureItems(_:)` 更新變動 row，避免傳統 index-path mutation 路線。
- ViewController lifecycle control：`viewWillAppear` 啟動更新，`viewWillDisappear` 停止更新。

## 模擬問題

這個 app 模擬一個即時 sensor dashboard：

- 從 repository 載入 sensor 清單。
- app 啟動時載入初始 metric snapshot。
- push-style source 持續送出高頻 metric updates。
- update 寫入 actor-backed store。
- UI 只取得 changed sensor IDs，並只更新受影響的 rows。

## 架構

```text
Repository / Update Source
          |
          v
SensorManager / MetricManager / MetricUpdateManager
          |
          v
MetricStoreActor
          |
          v
snapshot(for:) / changedIDs
          |
          v
SensorListViewModel
          |
          v
SwiftUI app target / UIKit app target
```

## 核心設計選擇

`MetricStoreActor` 集中管理 mutable metric state。這讓寫入同步變得明確，也避免 UI 或 managers 各自持有一份可能不同步的資料。

`MetricUpdateManager` 負責 update stream lifecycle。它可以安全地 start / stop source、消費 batch updates、套用更新到 store，並只輸出真正有變動的 sensor IDs。

`MetricsFeedManager` 是 ViewModel 使用的 facade。ViewModel 不需要知道資料來自 mock repository、真實 API，或 WebSocket source。

SwiftUI tab host 明確擁有 feed lifecycle。切到 Sensor tab 時啟動 live update pipeline；離開 Sensor tab 時停止更新，避免 inactive screen 繼續消耗事件。

UIKit 版本拆成獨立 target 與 scheme。它共用核心 feed managers、store、repositories 與 update source，但擁有自己的 `SceneDelegate` 與 `SensorListViewController` presentation layer。

## 為什麼做這個專案

這個 repository 被整理成作品集專案，用來展示：

- 即時更新壓力下的系統拆解能力。
- Swift Concurrency 的實務使用：`async/await`、`AsyncStream`、`Task`、`actor`。
- UI performance 思維：coalescing、deduplication、row-level updates。
- 透過 protocols 與 dependency injection 建立可測試邊界。

## 執行方式

1. 用 Xcode 開啟 `RealTimeMetricsDemo.xcodeproj`。
2. SwiftUI 版本選擇 `RealTimeMetricsDemo` scheme。
3. UIKit 版本選擇 `RealTimeMetricsDemoUIKit` scheme。
4. Run。

## 測試

在 Xcode 執行 `RealTimeMetricsDemoTests` target。

主要測試涵蓋：

- 同一批資料內的重複更新會保留最新值。
- 沒有變動的值不會產生 false-positive row update。
- 初始 metric loading 會先寫入 store，再回傳資料給 UI。
- update manager 的 start / stop 行為安全且可重複。
