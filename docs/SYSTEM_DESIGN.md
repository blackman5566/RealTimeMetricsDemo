# Real-Time Metrics Monitoring Demo（iOS 系統設計展示專案）

本專案是一個 **即時資料監控系統** 的 iOS 架構與實作示範。它原本來自一份技術練習，但這個版本已重新整理成更通用的作品集專案，主題聚焦在：

- 高頻即時資料更新
- 可替換資料來源，例如 Mock source / WebSocket source
- thread-safe 狀態管理
- UI 局部更新策略
- SwiftUI / UIKit 共用同一套核心資料流
- 可測試、可維護、可擴充的系統邊界設計

重點不在 UI 視覺，而在展示如何把一個「會持續收到資料、需要穩定更新 UI、又必須避免狀態混亂」的需求，整理成清楚的資料流與可替換架構。

---

## 開發時間說明（投入時間）

- **開發期間**：2026/01/10 ～ 2026/01/11 上午
- **實際投入工時**：約 1.5 天

### 時間分配概覽

- 架構設計與資料流規劃（Repository / Manager / Store / ViewModel）
- Swift Concurrency 建模（async/await、AsyncStream、actor、Task lifecycle）
- 高頻更新效能策略（coalesce / dedup / UI flush）
- SwiftUI Demo
- UIKit Demo 追加，沿用同一套核心架構
- 單元測試撰寫與穩定性驗證
- README 與設計說明整理

> 本專案刻意控制在技術練習的合理工時範圍內。  
> 目標不是堆滿功能，而是展示「可上線系統的架構骨架」與「面對高頻資料流時的設計判斷」。

---

## 版本資訊

### v1.0.0 - SwiftUI 版本

- 以 SwiftUI 建立完整 UI Demo
- 使用 MVVM + Store 建立單向資料流
- 使用 Swift Concurrency 作為核心非同步模型
- 支援高頻更新下的 row-level 更新策略
- 透過 Composition Root 管理依賴注入
- 可替換 Mock / Real-time source
- 單元測試覆蓋核心不變量

### v1.1.0 - UIKit 版本

- 新增 UIKit Demo App，與 SwiftUI App 並存
- SwiftUI / UIKit 共用同一套 Domain / Data / Update pipeline
- UIKit 使用 modern table update strategy：Diffable Data Source + reconfigureItems
- 切換 tab / view lifecycle 時會暫停更新，回到畫面後再恢復
- 透過 Xcode Scheme 切換執行目標：
  - `RealTimeMetricsDemo`：SwiftUI App
  - `RealTimeMetricsDemoUIKit`：UIKit App

> UIKit 版本是「額外展示層」，不是第二套系統。  
> 核心架構不複製、不分叉，保持單一資料流與單一狀態來源。

---

## 如何執行

### SwiftUI 版本

1. 使用 Xcode 開啟專案
2. Scheme 選擇 `RealTimeMetricsDemo`
3. 執行

### UIKit 版本

1. 使用 Xcode 開啟專案
2. Scheme 選擇 `RealTimeMetricsDemoUIKit`
3. 執行

可以把它理解成「同一個系統，兩種 UI 外殼」：  
面試官要看 SwiftUI，就跑 SwiftUI target；要看 UIKit，就跑 UIKit target。

---

## 架構總覽

整體採用以下設計原則：

- MVVM
- Single Source of Truth
- Composition Root
- Dependency Injection
- Swift Concurrency
- UI framework independent core

### 單向資料流

```text
Repository / Real-time Source
            ↓
       Feed Manager
            ↓
        Store Actor
            ↓
 snapshot / changedIDs
            ↓
        ViewModel
            ↓
   SwiftUI View / UIKit ViewController
```

此資料流確保：

- 狀態集中，避免多份資料互相打架
- UI 不直接處理連線、同步、重連、資料合併等細節
- SwiftUI / UIKit 只在展示層分歧
- 資料來源可替換，但 ViewModel 與 UI 不需要知道資料來自 Mock 還是真實 WebSocket

---

## Swift Concurrency 使用場景

本專案選擇 Swift Concurrency 作為核心非同步模型，而不是把整條資料流建立在 callback 或 Combine pipeline 上。

### 1. 初始資料載入（async / await）

Repository 提供 async API，Feed Manager 負責：

1. 從 repository 取得初始資料
2. 寫入 Store Actor
3. 從 Store Actor 取得 snapshot
4. 交給 ViewModel 更新 UI state

設計重點：  
UI 初始化永遠只使用 store snapshot，避免資料來源分裂。

### 2. 即時資料推播（AsyncStream + Task）

Real-time source 提供 `AsyncStream<[Metric]>`，每個事件代表一批資料更新。

Feed Manager 在背景 Task 中消費 stream：

- 套用更新至 Store Actor
- coalesce 同批重複資料
- dedup 無變動資料
- 對外輸出真正有變動的 IDs

此模型適合：

- WebSocket
- Server-sent events
- 高頻 sensor updates
- 需要可取消、可重啟的連線生命週期

### 3. UI Flush（節流）

高頻資料不應該每筆都直接觸發 UI 更新。Feed Manager 可將短時間內多次變更合併後再通知 UI，降低主執行緒壓力。

---

## Thread-Safe 與資料一致性設計

### Store Actor（Single Source of Truth）

所有即時資料狀態集中在 Store Actor。

使用 actor 的目的：

- 保證同一時間只有一個寫入者
- 避免共享 mutable state
- 不需要手動 lock / queue
- 讓更新順序可推理

### Batch Update Strategy

Store 在套用 batch update 時會做：

- **Coalesce**：同一批資料內，同一個 ID 只保留最後一筆
- **Dedup**：新舊值相同則視為 no-op
- **Changed IDs only**：只回傳真正有變動的 ID，避免 UI 白更新

這讓系統可以承受高頻更新，而不是每次事件都整頁重算、整頁 reload。

---

## UI 更新策略

### SwiftUI

SwiftUI 版本由 ViewModel 持有畫面狀態，View 只負責 render。

設計重點：

- View 不直接知道資料來源
- View 不處理連線生命週期
- ViewModel 將 store snapshot 轉成 UI state

### UIKit

UIKit 版本使用：

- `UITableViewDiffableDataSource`
- snapshot 初始載入
- `reconfigureItems` 做局部更新
- view lifecycle 控制 start / stop update stream

設計重點：

- 初次載入才建立完整 snapshot
- 後續高頻更新只 reconfigure 有變動的 row
- 切換 tab 或畫面離開時停止更新，避免背景畫面繼續消耗資源
- 回到畫面後重新啟動資料更新

這比傳統 `reloadData()` 或大量 `reloadRows(at:)` 更符合現代 UIKit 的資料更新方式。

---

## 依賴注入與可替換資料來源

本專案透過 Composition Root 集中建立依賴。

下層模組只依賴 protocol，不直接 new 具體實作，因此可以替換：

- Mock repository
- Real repository
- Mock real-time source
- WebSocket real-time source
- 測試用 manual source

概念上：

```swift
protocol MetricUpdateSource {
    func makeStream() -> AsyncStream<[Metric]>
}
```

Mock source 與 WebSocket source 只要符合同一個 protocol，Manager / Store / ViewModel / UI 都不需要改。

---

## 關於 WebSocket、Token Refresh 與資料邊界

這是本專案最重要的設計判斷之一。

我的看法是：  
**只要依賴注入與資料流邊界切得乾淨，接入 WebSocket 本身不應該影響 UI、ViewModel 或 Store。**

WebSocket 的複雜度應該被收斂在 source / session manager 這一層，例如：

- 建立連線
- 接收 message
- parse payload
- token refresh
- reconnect
- heartbeat
- backoff retry
- 將 raw event 轉成 domain update
- output 成 `AsyncStream<[Metric]>`

也就是說，WebSocket 是資料來源實作細節，不應該滲透到 UI 層。

### Token Refresh 應該放在哪裡？

Token refresh 不應該由 ViewModel 或 ViewController 處理。比較合理的位置是：

```text
AuthenticatedWebSocketClient
            ↓
Reconnect / Refresh Policy
            ↓
MetricUpdateSource
            ↓
Feed Manager
```

當 token 過期時，source/session manager 可以：

1. 暫停或關閉目前連線
2. 透過 AuthService refresh token
3. 使用新 token 重新連線
4. 重新訂閱需要的 channel
5. 繼續輸出 domain update

對上層來說，這仍然是一條 `AsyncStream<[Metric]>`。

### Refresh 期間如果收到資料怎麼辦？

這取決於產品需求，但架構上可以明確定義策略：

- **Drop**：refresh 期間丟棄舊 session event，避免套用過期連線資料
- **Buffer**：短時間暫存 event，refresh 成功後再套用
- **Resync**：refresh / reconnect 後重新拉一次 snapshot，再接續 stream

對即時監控系統，我會優先選擇：

```text
Reconnect → Fetch latest snapshot → Resume stream
```

原因是高頻資料通常重視最新狀態，而不是每一筆中間事件都不可遺失。重新同步 snapshot 可以避免 refresh 期間 event 順序與資料缺口造成狀態不一致。

### 快取與排序怎麼處理？

快取與排序不應該散落在 UI。

比較合理的責任切法：

- Source：處理連線、認證、raw event parsing
- Repository：處理初始 snapshot / remote fetch / local cache
- Store Actor：維護目前最新狀態與一致性
- ViewModel：將 domain snapshot 轉成 UI state，包含 display sorting
- UI：只 render ViewModel 給的狀態

如果排序是 domain rule，例如 priority、status、updatedAt，應該在 ViewModel 或 dedicated presenter/sorter 處理。UI 不應該一邊收 update 一邊自己決定資料真相。

---

## 對 LinkedIn 回應問題的技術判斷

有人提到：「如果同時要更新 N 筆資料，更新到一半 token 過期，要怎麼 refresh、怎麼接續、怎麼處理快取與排序？」

這個問題本身是合理的，但它不是 UI table update 的問題，也不是 ViewModel 應該直接處理的問題。

更精準地說，它屬於：

- connection/session boundary
- auth boundary
- repository consistency
- store resync strategy

本專案的回答是：

1. 用依賴注入讓 WebSocket source 可替換
2. 用 source/session manager 封裝 token refresh 與 reconnect
3. 用 Store Actor 作為唯一狀態來源
4. refresh/reconnect 後以 snapshot resync 修正資料缺口
5. UI 永遠只吃 ViewModel 輸出的 snapshot / changedIDs

所以接入真實 WebSocket 時，主要修改點應該集中在 source / repository / auth service，而不是牽動整個 app。

這也是本專案設計依賴注入與單向資料流的原因。

---

## AppEnvironment（效能與壓測參數集中管理）

本專案透過 `AppEnvironment` 集中管理即時資料系統的可調整參數。

設計目的：

- 將效能策略與業務邏輯解耦
- 避免更新頻率、batch size、UI flush interval 散落在各層
- 方便 Mock、測試、壓測、Demo 模式切換
- 讓系統瓶頸可以被觀察與調整

範例：

```swift
public struct AppEnvironment: Sendable {
    public var updatesPerSecond: TimeInterval
    public var maxUpdatesPerTick: Int
    public var enableUIFlush: Bool
    public var uiFlushInterval: TimeInterval
}
```

參數含義：

- `updatesPerSecond`：控制推播頻率，用於模擬不同負載
- `maxUpdatesPerTick`：控制單次 batch 最大更新量
- `enableUIFlush`：控制是否合併 UI 更新
- `uiFlushInterval`：控制 UI 更新節流時間

簡單說，`AppEnvironment` 讓這個 demo 不只是能跑，而是可以被調參、壓測、觀察。

---

## 單元測試

本專案測試重點是鎖住架構不變量，而不是只測語法。

### Manager Tests

- 初始資料一定寫入 store
- UI 初始化只能使用 store snapshot
- start() 具備冪等性，避免重複訂閱
- stop() 後不再接收更新

### Store Actor Tests

- coalesce：同批重複 ID 合併
- dedup：無變動更新不回報
- snapshot 僅回傳存在的 IDs
- 高頻 batch update 後狀態仍一致

### Update Pipeline Tests

- mock source 可以穩定產生事件
- manual source 可避免 time-based flaky test
- flush 行為可預期

---

## 整體總結

這個專案展示的不是「某個特定題目」，而是一套可遷移到多種即時產品的設計能力：

- Swift Concurrency 建模即時事件流
- actor 保證 thread-safe 狀態管理
- 高頻更新下的 coalesce / dedup / flush
- UI 局部更新，避免整頁 reload
- SwiftUI / UIKit 共用同一套核心架構
- 依賴注入讓 Mock / Real source 可替換
- WebSocket、token refresh、reconnect 被限制在正確邊界內
- 單元測試鎖住關鍵設計不變量

---

## 作者（Author）

Allen Hsu（許佳豪）  
iOS Engineer / System-Oriented Developer

> 這份專案的目的不是展示用了多少技術名詞，而是展示：  
> 在即時、高頻、可擴充的系統中，如何把資料流、狀態一致性、UI 更新與外部連線邊界切清楚。
