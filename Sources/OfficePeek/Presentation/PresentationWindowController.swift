import AppKit
import SwiftUI
import OfficePeekKit

/// 演示 presenter 抽象（`AppState` 依赖它，测试注入假实现）
@MainActor
protocol PresentationPresenting: AnyObject {
    /// 由外部（文档关闭/切换）主动结束演示；不回调 onExit
    func dismiss()
}

struct PresentationLaunchRequest {
    let fileURL: URL
    let slideCount: Int
    let startSlide: Int
    let screen: NSScreen?
    let placeholders: [Int: NSImage]
}

typealias PresentationPresenterFactory = @MainActor (
    PresentationLaunchRequest,
    @escaping @MainActor (Int) -> Void
) -> any PresentationPresenting

/// 可成为 key 的无边框窗口
final class PresentationWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 在 actor 边界前提取 AppKit 事件值，避免将非 Sendable 的 NSEvent 传入 MainActor 闭包。
private enum MonitoredPresentationEvent: Sendable {
    case keyDown(
        windowID: ObjectIdentifier?,
        keyCode: UInt16,
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags
    )
    case scrollWheel(
        windowID: ObjectIdentifier?,
        deltaX: CGFloat,
        deltaY: CGFloat,
        hasPreciseDeltas: Bool,
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase,
        timestamp: TimeInterval
    )
    case rightMouseDown(windowID: ObjectIdentifier?)

    var windowID: ObjectIdentifier? {
        switch self {
        case .keyDown(let windowID, _, _, _),
             .scrollWheel(let windowID, _, _, _, _, _, _),
             .rightMouseDown(let windowID):
            return windowID
        }
    }
}

/// 无边框全屏演示窗口控制器：覆盖目标屏幕、隐藏 Dock/菜单栏、本地监听键盘/滚动/右键
@MainActor
final class PresentationWindowController: NSWindowController, NSWindowDelegate, PresentationPresenting {
    private let viewModel: PresentationViewModel
    private let targetScreen: NSScreen
    private let onExit: @MainActor (Int) -> Void
    private var scrollAccumulator = PresentationScrollAccumulator()
    private var eventMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var previousPresentationOptions: NSApplication.PresentationOptions?
    private var isTornDown = false

    private final class EmptyPresenter: PresentationPresenting {
        func dismiss() {}
    }

    static func present(
        _ request: PresentationLaunchRequest,
        onExit: @escaping @MainActor (Int) -> Void
    ) -> any PresentationPresenting {
        guard let controller = PresentationWindowController(request: request, onExit: onExit) else {
            Task { @MainActor in
                onExit(request.startSlide)
            }
            return EmptyPresenter()
        }
        controller.show()
        return controller
    }

    init?(request: PresentationLaunchRequest, onExit: @escaping @MainActor (Int) -> Void) {
        guard let screen = request.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return nil
        }
        let scale = screen.backingScaleFactor
        let pixelSize = CGSize(width: screen.frame.width * scale, height: screen.frame.height * scale)
        let renderer = PresentationSlideRenderer(fileURL: request.fileURL, targetPixelSize: pixelSize)
        let viewModel = PresentationViewModel(
            renderer: renderer,
            slideCount: request.slideCount,
            startSlide: request.startSlide,
            placeholders: request.placeholders
        )

        let window = PresentationWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenNone]
        window.acceptsMouseMovedEvents = true
        window.contentView = NSHostingView(
            rootView: PresentationView(viewModel: viewModel, renderer: renderer)
        )
        window.setFrame(screen.frame, display: true)

        self.viewModel = viewModel
        self.targetScreen = screen
        self.onExit = onExit
        super.init(window: window)
        window.delegate = self
        viewModel.onExit = { [weak self] lastSlide in
            self?.finish(lastSlide: lastSlide)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        let currentOptions = NSApp.presentationOptions
        if !currentOptions.contains(.fullScreen) {
            previousPresentationOptions = currentOptions
            NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        }
        installEventMonitor()
        observeScreenChanges()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        viewModel.start()
    }

    func dismiss() {
        tearDown()
    }

    func windowWillClose(_ notification: Notification) {
        finish(lastSlide: viewModel.session.currentSlide)
    }

    // MARK: - 事件

    private func installEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .scrollWheel, .rightMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            let windowID = event.window.map { ObjectIdentifier($0) }
            let input: MonitoredPresentationEvent
            switch event.type {
            case .keyDown:
                input = .keyDown(
                    windowID: windowID,
                    keyCode: event.keyCode,
                    charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                    modifierFlags: event.modifierFlags
                )
            case .scrollWheel:
                input = .scrollWheel(
                    windowID: windowID,
                    deltaX: event.scrollingDeltaX,
                    deltaY: event.scrollingDeltaY,
                    hasPreciseDeltas: event.hasPreciseScrollingDeltas,
                    phase: event.phase,
                    momentumPhase: event.momentumPhase,
                    timestamp: event.timestamp
                )
            case .rightMouseDown:
                input = .rightMouseDown(windowID: windowID)
            default:
                return event
            }
            let consumed = MainActor.assumeIsolated {
                self.consume(input)
            }
            return consumed ? nil : event
        }
    }

    /// 返回 true 表示事件已被演示模式消费
    private func consume(_ event: MonitoredPresentationEvent) -> Bool {
        guard let window, event.windowID == ObjectIdentifier(window) else { return false }
        switch event {
        case .keyDown(_, let keyCode, let charactersIgnoringModifiers, let modifierFlags):
            guard let command = PresentationKeyMap.command(
                keyCode: keyCode,
                charactersIgnoringModifiers: charactersIgnoringModifiers,
                modifierFlags: modifierFlags
            ) else {
                return false
            }
            viewModel.handle(command)
            return true
        case .scrollWheel(_, let deltaX, let deltaY, let hasPreciseDeltas, let phase, let momentumPhase, let timestamp):
            if let command = scrollAccumulator.consume(
                deltaX: deltaX,
                deltaY: deltaY,
                hasPreciseDeltas: hasPreciseDeltas,
                phase: phase,
                momentumPhase: momentumPhase,
                timestamp: timestamp
            ) {
                viewModel.handle(command)
            }
            return true
        case .rightMouseDown:
            viewModel.handle(.previous)
            return true
        }
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleScreenChange()
            }
        }
    }

    private func handleScreenChange() {
        guard !isTornDown else { return }
        let targetID = Self.screenNumber(targetScreen)
        if let screen = NSScreen.screens.first(where: { Self.screenNumber($0) == targetID }) {
            window?.setFrame(screen.frame, display: true)
        } else {
            finish(lastSlide: viewModel.session.currentSlide)
        }
    }

    private static func screenNumber(_ screen: NSScreen) -> NSNumber? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    }

    // MARK: - 收尾

    private func finish(lastSlide: Int) {
        guard !isTornDown else { return }
        tearDown()
        onExit(lastSlide)
    }

    private func tearDown() {
        guard !isTornDown else { return }
        isTornDown = true
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        viewModel.finish()
        if let previousPresentationOptions {
            NSApp.presentationOptions = previousPresentationOptions
            self.previousPresentationOptions = nil
        }
        window?.delegate = nil
        window?.orderOut(nil)
        window?.close()
    }
}
