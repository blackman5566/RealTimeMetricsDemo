//
//  Untitled.swift
//  RealTimeMetricsDemo
//
//  Created by 許佳豪 on 2026/1/10.
//

import Foundation
import QuartzCore
import Observation

/// FPSCounter：用 CADisplayLink 計算畫面 FPS（每秒更新一次數字）
///
/// 用途：
/// - 作業加分：顯示 FPS 指標，觀察高頻更新下是否掉幀
/// 注意：
/// - 這是 Debug 用，建議只在 DEBUG 版顯示
@MainActor
@Observable
public final class FPSCounter {

    /// 目前 FPS（每秒更新一次）
    public private(set) var fps: Int = 0

    /// DisplayLink（跟螢幕刷新同步）
    private var link: CADisplayLink?

    /// 上次統計時間點
    private var lastTime: CFTimeInterval = 0

    /// 這一秒累積的 frame 數
    private var frameCount: Int = 0

    public init() {}

    /// 開始計算 FPS
    public func start() {
        stop() // 防呆：避免重複 start 造成多條 link

        lastTime = CACurrentMediaTime()
        frameCount = 0
        fps = 0

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// 停止計算 FPS
    public func stop() {
        link?.invalidate()
        link = nil
    }

    /// 每一幀會被呼叫一次
    @objc private func tick() {
        frameCount += 1

        let now = CACurrentMediaTime()
        let delta = now - lastTime

        /// 每過 1 秒更新一次 fps 數字
        if delta >= 1.0 {
            fps = Int(round(Double(frameCount) / delta))
            lastTime = now
            frameCount = 0
        }
    }
}

