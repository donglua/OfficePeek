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
