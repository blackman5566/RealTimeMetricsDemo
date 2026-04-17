//
//  SensorListViewController.swift
//  RealTimeMetricsDemoUIKit
//
//  Created by Codex on 2026/4/17.
//

import UIKit
import SwiftUI
import Combine

final class SensorListViewController: UIViewController {
    // MARK: - Dependencies（依賴注入）
    /// ViewModel 由外部注入，VC 不負責建立資料來源（保持邊界清楚）
    private let viewModel: SensorListViewModel

    // MARK: - UI
    private let demoTableView = UITableView(frame: .zero, style: .plain)

    // FPS 顯示（SwiftUI overlay）
    var fpsCounter = FPSCounter()

    // Combine 生命週期容器
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Diffable Data Source（iOS 13+）
    private typealias DataSource = UITableViewDiffableDataSource<Int, SensorID>
    private var dataSource: DataSource!

    // MARK: - Cache（效能最佳化：O(1) 查找）
    /// order：列表的顯示順序（只保存 ID）
    /// 用於 snapshot.appendItems(order)
    private var order: [SensorID] = []

    /// sensorByID：用 SensorID 快速拿到 Sensor（字典 O(1)）
    /// 避免 cellForRow 每次用 first(where:) O(n) 掃陣列
    private var sensorByID: [SensorID: Sensor] = [:]

    // MARK: - High Frequency Update Coalescing（高頻更新合併）
    /// pendingReloadIDs：把多次 changedIDs 暫存起來，下一個 runloop 再一起更新
    /// 目的：避免每次收到更新就 apply snapshot（會造成 FPS 掉）
    private var pendingReloadIDs = Set<SensorID>()

    /// scheduledFlush：確保同一個 runloop 只排程一次 flush
    private var scheduledFlush = false

    // MARK: - Init
    init(viewModel: SensorListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupInitValues()
        setupTableView()
        setupDataSource()
        setupFPSOverlay()
        setupDebugHUD()
        bindViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.onAppear()
        fpsCounter.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.onDisappear()
        fpsCounter.stop()
    }

    deinit {
        /// Combine 訂閱在 VC 釋放時會自動取消
        /// 這行不是必需，但保留也無害（顯式清理）
        cancellables.removeAll()
    }
}

// MARK: - Binding（與 ViewModel 綁定）
private extension SensorListViewController {

    func bindViewModel() {
        /// initialReload：代表「列表結構」發生變動（初次載入 / 重新排序 / 重新建立資料）
        /// 這時候我們要：
        /// 1) 重建 cache（order + sensorByID）
        /// 2) 套用完整 snapshot
        viewModel.initialReload
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.rebuildCacheFromViewModel()
                self?.applyInitialSnapshot()
            }
            .store(in: &cancellables)

        /// partialReload：代表「內容」變動（例如 metric 更新）
        /// 這時候通常「順序不變」，不用重建 cache
        /// 我們只需要 reloading 對應的 item（但要合併高頻更新）
        viewModel.partialReload
            .receive(on: DispatchQueue.main)
            .sink { [weak self] changedIDs in
                self?.enqueuePartialReload(changedIDs: changedIDs)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Cache（從 ViewModel 建立快取）
private extension SensorListViewController {

    func rebuildCacheFromViewModel() {
        /// ✅ 只在「結構變動」時重建，不要每次 partialReload 都做
        /// 因為重建字典本身也需要成本，高頻做會反而掉效能

        // 1) 保存「列表順序」
        order = viewModel.sensors.map(\.sensorID)

        // 2) 建立 SensorID -> Sensor 的字典（O(1) 查找）
        sensorByID = Dictionary(
            uniqueKeysWithValues: viewModel.sensors.map { ($0.sensorID, $0) }
        )
    }
}

// MARK: - Diffable（資料源 + Snapshot 更新）
private extension SensorListViewController {

    func setupDataSource() {
        dataSource = DataSource(tableView: demoTableView) { [weak self] tableView, indexPath, sensorID in
            guard let self else { return UITableViewCell() }

            let cell = tableView.dequeueReusableCell(
                withIdentifier: MetricTableViewCell.reuseID,
                for: indexPath
            ) as! MetricTableViewCell

            // ✅ O(1) 查找，避免 first(where:) O(n)
            guard let sensor = self.sensorByID[sensorID] else { return cell }

            let metric = self.viewModel.metricByID[sensorID]
            cell.configure(sensor: sensor, metric: metric)
            return cell
        }
    }

    func applyInitialSnapshot() {
        /// 初次載入 / 結構變動：重建完整 snapshot
        var snapshot = NSDiffableDataSourceSnapshot<Int, SensorID>()
        snapshot.appendSections([0])
        snapshot.appendItems(order, toSection: 0)

        /// 高頻情境通常關掉動畫更穩
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: 高頻更新合併：enqueue → flush

    func enqueuePartialReload(changedIDs: [SensorID]) {
        /// 目的：把多次更新合併成一次 apply，避免 snapshot apply 過於頻繁導致掉幀
        guard !changedIDs.isEmpty else { return }

        // 先把 changedIDs 存到 Set，避免重複
        changedIDs.forEach { pendingReloadIDs.insert($0) }

        // 同一個 runloop 只排程一次 flush
        guard !scheduledFlush else { return }
        scheduledFlush = true

        // 下一個 runloop 再一次更新（合併同一段時間的更新）
        DispatchQueue.main.async { [weak self] in
            self?.flushPartialReload()
        }
    }

    func flushPartialReload() {
        scheduledFlush = false
        guard !pendingReloadIDs.isEmpty else { return }

        var snapshot = dataSource.snapshot()

        /// reloadItems 只能 reload snapshot 內存在的 item
        /// 所以要先過濾，避免 reload 不存在的 id
        let existing = Set(snapshot.itemIdentifiers)
        let valid = pendingReloadIDs.filter { existing.contains($0) }
        pendingReloadIDs.removeAll()

        guard !valid.isEmpty else { return }

        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems(Array(valid))
        } else {
            // ✅ iOS 13–14: reloadItems
            snapshot.reloadItems(Array(valid))
        }

        /// 高頻更新：建議關動畫，讓 tableView 更穩定
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UI Setup（畫面組裝）
private extension SensorListViewController {

    func setupInitValues() {
        title = "Sensors"
        view.backgroundColor = .systemBackground
    }

    func setupTableView() {
        demoTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(demoTableView)

        NSLayoutConstraint.activate([
            demoTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            demoTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            demoTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            demoTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        demoTableView.register(MetricTableViewCell.self, forCellReuseIdentifier: MetricTableViewCell.reuseID)
        demoTableView.rowHeight = 90

        /// DiffableDataSource 會接管 dataSource
        /// 所以這裡不要再手動指定 demoTableView.dataSource = self
        demoTableView.dataSource = nil
    }

    func setupFPSOverlay() {
        let host = UIHostingController(rootView: FPSOverlayView(counter: fpsCounter))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(host)
        view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            host.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            host.view.widthAnchor.constraint(equalToConstant: 80)
        ])

        host.didMove(toParent: self)
    }

    func setupDebugHUD() {
        let host = UIHostingController(rootView: DebugHUDView(viewModel: viewModel))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(host)
        view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            host.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12)
        ])

        host.didMove(toParent: self)
    }
}
