import AppKit
import OfficePeekKit

/// 光标控制抽象（便于单测替换）
@MainActor
protocol PresentationCursorControlling {
    func hide()
    func unhide()
    func hideUntilMouseMoves()
}

struct SystemPresentationCursor: PresentationCursorControlling {
    nonisolated init() {}

    func hide() { NSCursor.hide() }
    func unhide() { NSCursor.unhide() }
    func hideUntilMouseMoves() { NSCursor.setHiddenUntilMouseMoves(true) }
}

/// 演示视图模型：持有会话状态机与渲染器，管理 HUD 自动隐藏、光标与激光笔
@MainActor
final class PresentationViewModel: ObservableObject {
    @Published private(set) var session: PresentationSession
    @Published private(set) var isHUDVisible = false
    @Published private(set) var laserPoint: CGPoint?

    let renderer: PresentationSlideRenderer
    let placeholders: [Int: NSImage]
    var onExit: ((Int) -> Void)?

    private(set) var isCursorHiddenByLaser = false
    private let cursor: any PresentationCursorControlling
    private let hudAutoHideDelay: Duration
    private var hudHideTask: Task<Void, Never>?
    private var isFinished = false

    init(
        renderer: PresentationSlideRenderer,
        slideCount: Int,
        startSlide: Int,
        placeholders: [Int: NSImage] = [:],
        cursor: any PresentationCursorControlling = SystemPresentationCursor(),
        hudAutoHideDelay: Duration = .milliseconds(2500)
    ) {
        self.renderer = renderer
        self.session = PresentationSession(slideCount: slideCount, startSlide: startSlide)
        self.placeholders = placeholders
        self.cursor = cursor
        self.hudAutoHideDelay = hudAutoHideDelay
    }

    func start() {
        renderer.show(slide: session.currentSlide)
        revealHUD()
    }

    func handle(_ command: PresentationCommand) {
        guard !isFinished else { return }
        let previousSlide = session.currentSlide
        if session.apply(command) == .exit {
            requestExit()
            return
        }
        if command == .toggleLaser {
            syncLaserCursor()
        }
        let slideChanged = session.currentSlide != previousSlide
        if slideChanged {
            renderer.show(slide: session.currentSlide)
        }
        if session.blankMode != .none {
            hideHUD()
        } else if slideChanged {
            revealHUD()
        }
    }

    func pointerMoved(to point: CGPoint?) {
        guard !isFinished else { return }
        laserPoint = session.isLaserEnabled ? point : nil
        if point != nil, session.blankMode == .none {
            revealHUD()
        }
    }

    func requestExit() {
        guard !isFinished else { return }
        onExit?(session.currentSlide)
    }

    /// 退出收尾：取消计时与渲染，兜底恢复被激光笔隐藏的光标（幂等）
    func finish() {
        guard !isFinished else { return }
        isFinished = true
        hudHideTask?.cancel()
        hudHideTask = nil
        renderer.cancelAll()
        if isCursorHiddenByLaser {
            cursor.unhide()
            isCursorHiddenByLaser = false
        }
        laserPoint = nil
    }

    private func syncLaserCursor() {
        if session.isLaserEnabled, !isCursorHiddenByLaser {
            cursor.hide()
            isCursorHiddenByLaser = true
        } else if !session.isLaserEnabled, isCursorHiddenByLaser {
            cursor.unhide()
            isCursorHiddenByLaser = false
        }
        if !session.isLaserEnabled {
            laserPoint = nil
        }
    }

    private func revealHUD() {
        isHUDVisible = true
        hudHideTask?.cancel()
        let delay = hudAutoHideDelay
        hudHideTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.isHUDVisible = false
            if !self.session.isLaserEnabled {
                self.cursor.hideUntilMouseMoves()
            }
        }
    }

    private func hideHUD() {
        hudHideTask?.cancel()
        hudHideTask = nil
        isHUDVisible = false
    }
}
