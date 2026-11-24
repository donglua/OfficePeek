import Testing
import Foundation
import AppKit
@testable import OfficePeek
@testable import OfficePeekKit

@MainActor
final class FakePresentationCursor: PresentationCursorControlling {
    var hideCount = 0
    var unhideCount = 0
    var hideUntilMovesCount = 0

    func hide() { hideCount += 1 }
    func unhide() { unhideCount += 1 }
    func hideUntilMouseMoves() { hideUntilMovesCount += 1 }
}

@Suite("PresentationViewModel HUD、光标与激光笔")
struct PresentationViewModelTests {

    @MainActor
    private func makeViewModel(
        cursor: FakePresentationCursor,
        delay: Duration = .seconds(60)
    ) -> PresentationViewModel {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("vm-\(UUID().uuidString).pptx")
        let renderer = PresentationSlideRenderer(fileURL: missing, targetPixelSize: CGSize(width: 100, height: 100))
        return PresentationViewModel(
            renderer: renderer,
            slideCount: 5,
            startSlide: 2,
            cursor: cursor,
            hudAutoHideDelay: delay
        )
    }

    @Test("翻页更新会话、驱动渲染器焦点并显示 HUD")
    @MainActor
    func navigationDrivesRendererAndHUD() {
        let cursor = FakePresentationCursor()
        let vm = makeViewModel(cursor: cursor)
        vm.start()
        #expect(vm.renderer.focusSlide == 2)
        #expect(vm.isHUDVisible)

        vm.handle(.next)
        #expect(vm.session.currentSlide == 3)
        #expect(vm.renderer.focusSlide == 3)
        vm.finish()
    }

    @Test("Esc 触发 onExit 并回传当前页")
    @MainActor
    func cancelRequestsExit() {
        let cursor = FakePresentationCursor()
        let vm = makeViewModel(cursor: cursor)
        var exitedAt: Int?
        vm.onExit = { exitedAt = $0 }
        vm.start()
        vm.handle(.cancel)
        #expect(exitedAt == 2)
        vm.finish()
    }

    @Test("激光笔隐藏/恢复光标成对调用，finish 兜底恢复且幂等")
    @MainActor
    func laserCursorPairing() {
        let cursor = FakePresentationCursor()
        let vm = makeViewModel(cursor: cursor)
        vm.start()

        vm.handle(.toggleLaser)
        #expect(cursor.hideCount == 1)
        #expect(vm.isCursorHiddenByLaser)
        vm.pointerMoved(to: CGPoint(x: 10, y: 20))
        #expect(vm.laserPoint == CGPoint(x: 10, y: 20))

        vm.handle(.toggleLaser)
        #expect(cursor.unhideCount == 1)
        #expect(vm.laserPoint == nil)

        vm.handle(.toggleLaser)
        #expect(cursor.hideCount == 2)
        vm.finish()
        #expect(cursor.unhideCount == 2)
        vm.finish()
        #expect(cursor.unhideCount == 2)
    }

    @Test("黑屏隐藏 HUD 且鼠标移动不再唤出")
    @MainActor
    func blankHidesHUD() {
        let cursor = FakePresentationCursor()
        let vm = makeViewModel(cursor: cursor)
        vm.start()
        vm.handle(.toggleBlack)
        #expect(!vm.isHUDVisible)
        vm.pointerMoved(to: CGPoint(x: 1, y: 1))
        #expect(!vm.isHUDVisible)
        vm.finish()
    }

    @Test("HUD 超时自动隐藏并让系统光标在静止时隐藏")
    @MainActor
    func hudAutoHides() async throws {
        let cursor = FakePresentationCursor()
        let vm = makeViewModel(cursor: cursor, delay: .milliseconds(30))
        vm.start()
        #expect(vm.isHUDVisible)
        try await Task.sleep(for: .milliseconds(200))
        #expect(!vm.isHUDVisible)
        #expect(cursor.hideUntilMovesCount == 1)
        vm.finish()
    }
}

@MainActor
final class FakePresenter: PresentationPresenting {
    var dismissCount = 0
    func dismiss() { dismissCount += 1 }
}

@Suite("AppState 演示启动与结束")
struct AppStatePresentationTests {

    @MainActor
    private final class FactoryRecorder {
        var requests: [PresentationLaunchRequest] = []
        var exitHandlers: [@MainActor (Int) -> Void] = []
        var presenters: [FakePresenter] = []
    }

    @MainActor
    private func makeAppState(recorder: FactoryRecorder, dir: URL) -> AppState {
        let store = RecentFilesStore(storageURL: dir.appendingPathComponent("recent.json"))
        let appState = AppState(recentStore: store)
        appState.presenterFactory = { request, onExit in
            let presenter = FakePresenter()
            recorder.requests.append(request)
            recorder.exitHandlers.append(onExit)
            recorder.presenters.append(presenter)
            return presenter
        }
        return appState
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("officepeek-appstate-present-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("非 PPTX 文档不能启动演示")
    @MainActor
    func rejectsNonPptx() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let docxURL = dir.appendingPathComponent("doc.docx")
        try TestFixtures.writeMinimalFloatingDOCX(to: docxURL)

        let recorder = FactoryRecorder()
        let appState = makeAppState(recorder: recorder, dir: dir)
        appState.openDocument(at: docxURL)
        appState.startPresentation(.beginning)

        #expect(!appState.isPresenting)
        #expect(!appState.canStartPresentation)
        #expect(recorder.requests.isEmpty)
    }

    @Test("PPTX 启动演示、忽略重复启动、Esc 回调结束并 dismiss 不重复")
    @MainActor
    func startsAndEndsPresentation() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let pptxURL = dir.appendingPathComponent("deck.pptx")
        try TestFixtures.writeMinimalPPTX(to: pptxURL, slides: [
            (backgroundHex: "FF0000", title: "1"),
            (backgroundHex: "00FF00", title: "2"),
            (backgroundHex: "0000FF", title: "3")
        ])

        let recorder = FactoryRecorder()
        let appState = makeAppState(recorder: recorder, dir: dir)
        appState.openDocument(at: pptxURL)
        appState.presentSearch()
        #expect(appState.resolvePresentationSlideCount() == 3)

        appState.startPresentation(.currentSlide)
        #expect(appState.isPresenting)
        #expect(!appState.previewController.isSearchPresented)
        #expect(recorder.requests.count == 1)
        let request = try #require(recorder.requests.first)
        #expect(request.slideCount == 3)
        #expect(request.startSlide == 1)
        #expect(request.fileURL == pptxURL.standardizedFileURL)

        appState.startPresentation(.beginning)
        #expect(recorder.requests.count == 1)

        let onExit = try #require(recorder.exitHandlers.first)
        onExit(2)
        #expect(!appState.isPresenting)
        let presenter = try #require(recorder.presenters.first)
        #expect(presenter.dismissCount == 1)

        appState.endPresentation(lastSlide: 3)
        #expect(presenter.dismissCount == 1)
    }

    @Test("关闭或切换文档时自动结束演示")
    @MainActor
    func closingDocumentEndsPresentation() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let pptxURL = dir.appendingPathComponent("deck.pptx")
        try TestFixtures.writeMinimalPPTX(to: pptxURL, slides: [
            (backgroundHex: "FF0000", title: "1"),
            (backgroundHex: "00FF00", title: "2")
        ])

        let recorder = FactoryRecorder()
        let appState = makeAppState(recorder: recorder, dir: dir)
        appState.openDocument(at: pptxURL)
        appState.startPresentation(.beginning)
        #expect(appState.isPresenting)

        appState.closeDocument()
        #expect(!appState.isPresenting)
        let firstPresenter = try #require(recorder.presenters.first)
        #expect(firstPresenter.dismissCount == 1)

        appState.openDocument(at: pptxURL)
        appState.startPresentation(.beginning)
        #expect(appState.isPresenting)
        appState.openDocument(at: pptxURL)
        #expect(!appState.isPresenting)
        let secondPresenter = try #require(recorder.presenters.last)
        #expect(secondPresenter.dismissCount == 1)
    }
}
