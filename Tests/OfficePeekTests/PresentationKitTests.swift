import Testing
import Foundation
import AppKit
import CoreGraphics
@testable import OfficePeekKit

@Suite("PresentationSession 演示状态机")
struct PresentationSessionTests {

    @Test("起始页钳制与首末页边界翻页")
    func clampsStartAndNavigatesWithinBounds() {
        var session = PresentationSession(slideCount: 3, startSlide: 9)
        #expect(session.currentSlide == 3)

        session.apply(.next)
        #expect(session.currentSlide == 3)
        session.apply(.previous)
        #expect(session.currentSlide == 2)
        session.apply(.first)
        #expect(session.currentSlide == 1)
        session.apply(.previous)
        #expect(session.currentSlide == 1)
        session.apply(.last)
        #expect(session.currentSlide == 3)
        session.apply(.goTo(2))
        #expect(session.currentSlide == 2)
        session.apply(.goTo(99))
        #expect(session.currentSlide == 3)
        session.apply(.goTo(0))
        #expect(session.currentSlide == 1)

        let empty = PresentationSession(slideCount: 0, startSlide: 0)
        #expect(empty.slideCount == 1)
        #expect(empty.currentSlide == 1)
    }

    @Test("黑/白屏切换且翻页键只恢复画面不翻页")
    func blankModeTogglesAndNavigationOnlyRestores() {
        var session = PresentationSession(slideCount: 5, startSlide: 2)
        session.apply(.toggleBlack)
        #expect(session.blankMode == .black)
        session.apply(.toggleWhite)
        #expect(session.blankMode == .white)
        session.apply(.toggleWhite)
        #expect(session.blankMode == .none)

        session.apply(.toggleBlack)
        session.apply(.next)
        #expect(session.blankMode == .none)
        #expect(session.currentSlide == 2)

        session.apply(.toggleWhite)
        session.apply(.previous)
        #expect(session.blankMode == .none)
        #expect(session.currentSlide == 2)
    }

    @Test("Esc 优先级：清空跳页缓冲 → 退出黑白屏 → 退出演示")
    func cancelPriority() {
        var session = PresentationSession(slideCount: 5, startSlide: 1)
        session.apply(.toggleBlack)
        session.apply(.digit(3))

        let first = session.apply(.cancel)
        #expect(first == .none)
        #expect(session.jumpBuffer.isEmpty)
        #expect(session.blankMode == .black)

        let second = session.apply(.cancel)
        #expect(second == .none)
        #expect(session.blankMode == .none)

        let third = session.apply(.cancel)
        #expect(third == .exit)
    }

    @Test("数字跳页：缓冲上限、越界钳制、0 无效、空缓冲回车等同下一页")
    func digitJump() {
        var session = PresentationSession(slideCount: 20, startSlide: 1)
        session.apply(.digit(1))
        session.apply(.digit(2))
        #expect(session.jumpBuffer == "12")
        session.apply(.commitJump)
        #expect(session.currentSlide == 12)
        #expect(session.jumpBuffer.isEmpty)

        for digit in [9, 9, 9, 9, 9] {
            session.apply(.digit(digit))
        }
        #expect(session.jumpBuffer == "9999")
        session.apply(.commitJump)
        #expect(session.currentSlide == 20)

        session.apply(.digit(0))
        session.apply(.commitJump)
        #expect(session.currentSlide == 20)
        #expect(session.jumpBuffer.isEmpty)

        session.apply(.first)
        session.apply(.commitJump)
        #expect(session.currentSlide == 2)

        session.apply(.digit(5))
        session.apply(.next)
        #expect(session.jumpBuffer.isEmpty)
        #expect(session.currentSlide == 3)

        session.apply(.toggleBlack)
        session.apply(.digit(7))
        session.apply(.commitJump)
        #expect(session.currentSlide == 7)
        #expect(session.blankMode == .none)

        session.apply(.digit(12))
        #expect(session.jumpBuffer.isEmpty)
    }

    @Test("激光笔开关")
    func laserToggle() {
        var session = PresentationSession(slideCount: 2, startSlide: 1)
        #expect(!session.isLaserEnabled)
        session.apply(.toggleLaser)
        #expect(session.isLaserEnabled)
        session.apply(.toggleLaser)
        #expect(!session.isLaserEnabled)
    }

    @Test("PresentationStart 起始页计算")
    func startSlideResolution() {
        #expect(PresentationStart.beginning.startSlide(currentPage: 7, slideCount: 10) == 1)
        #expect(PresentationStart.currentSlide.startSlide(currentPage: 7, slideCount: 10) == 7)
        #expect(PresentationStart.currentSlide.startSlide(currentPage: 0, slideCount: 10) == 1)
        #expect(PresentationStart.currentSlide.startSlide(currentPage: 42, slideCount: 10) == 10)
        #expect(PresentationStart.currentSlide.startSlide(currentPage: 3, slideCount: 0) == 1)
    }
}

@Suite("PresentationKeyMap 键盘映射")
struct PresentationKeyMapTests {

    private func map(
        _ keyCode: UInt16,
        _ characters: String? = nil,
        _ flags: NSEvent.ModifierFlags = []
    ) -> PresentationCommand? {
        PresentationKeyMap.command(
            keyCode: keyCode,
            charactersIgnoringModifiers: characters,
            modifierFlags: flags
        )
    }

    @Test("方向键/空格/翻页键/回车/Home/End/Esc 按虚拟键码映射")
    func mapsSpecialKeys() {
        #expect(map(124) == .next)
        #expect(map(125) == .next)
        #expect(map(49, " ") == .next)
        #expect(map(121) == .next)
        #expect(map(123) == .previous)
        #expect(map(126) == .previous)
        #expect(map(51) == .previous)
        #expect(map(116) == .previous)
        #expect(map(36, "\r") == .commitJump)
        #expect(map(76) == .commitJump)
        #expect(map(115) == .first)
        #expect(map(119) == .last)
        #expect(map(53) == .cancel)
        #expect(map(124, nil, [.numericPad, .function]) == .next)
    }

    @Test("字母、标点与数字按字符映射且忽略大小写")
    func mapsCharacters() {
        #expect(map(45, "n") == .next)
        #expect(map(35, "p") == .previous)
        #expect(map(11, "b") == .toggleBlack)
        #expect(map(11, "B", [.shift]) == .toggleBlack)
        #expect(map(47, ".") == .toggleBlack)
        #expect(map(13, "w") == .toggleWhite)
        #expect(map(43, ",") == .toggleWhite)
        #expect(map(37, "l") == .toggleLaser)
        #expect(map(18, "1") == .digit(1))
        #expect(map(29, "0") == .digit(0))
        #expect(map(7, "x") == nil)
        #expect(map(7, nil) == nil)
    }

    @Test("带 ⌘/⌃/⌥ 修饰时透传给系统")
    func passesThroughModifiedKeys() {
        #expect(map(124, nil, [.command]) == nil)
        #expect(map(12, "q", [.command]) == nil)
        #expect(map(11, "b", [.control]) == nil)
        #expect(map(53, nil, [.option]) == nil)
    }
}

@Suite("PresentationScrollAccumulator 滚动与滑动")
struct PresentationScrollAccumulatorTests {

    @Test("触控板同一手势累计超过阈值仅触发一次，结束后可再次触发")
    func trackpadFiresOncePerGesture() {
        var acc = PresentationScrollAccumulator()
        let r1 = acc.consume(deltaX: 0, deltaY: -15, hasPreciseDeltas: true, phase: .began, momentumPhase: [], timestamp: 0)
        #expect(r1 == nil)
        let r2 = acc.consume(deltaX: 0, deltaY: -30, hasPreciseDeltas: true, phase: .changed, momentumPhase: [], timestamp: 0.02)
        #expect(r2 == .next)
        let r3 = acc.consume(deltaX: 0, deltaY: -80, hasPreciseDeltas: true, phase: .changed, momentumPhase: [], timestamp: 0.04)
        #expect(r3 == nil)
        let r4 = acc.consume(deltaX: 0, deltaY: 0, hasPreciseDeltas: true, phase: .ended, momentumPhase: [], timestamp: 0.06)
        #expect(r4 == nil)
        let r5 = acc.consume(deltaX: 0, deltaY: 50, hasPreciseDeltas: true, phase: .began, momentumPhase: [], timestamp: 0.5)
        #expect(r5 == .previous)
    }

    @Test("惯性阶段全部忽略")
    func ignoresMomentum() {
        var acc = PresentationScrollAccumulator()
        let r1 = acc.consume(deltaX: 0, deltaY: -120, hasPreciseDeltas: true, phase: [], momentumPhase: .changed, timestamp: 0)
        #expect(r1 == nil)
        let r2 = acc.consume(deltaX: 0, deltaY: -5, hasPreciseDeltas: false, phase: [], momentumPhase: .began, timestamp: 1)
        #expect(r2 == nil)
    }

    @Test("横向位移占主导时按横轴判定方向")
    func horizontalAxis() {
        var acc = PresentationScrollAccumulator()
        let r1 = acc.consume(deltaX: -50, deltaY: 10, hasPreciseDeltas: true, phase: .began, momentumPhase: [], timestamp: 0)
        #expect(r1 == .next)
        _ = acc.consume(deltaX: 0, deltaY: 0, hasPreciseDeltas: true, phase: .ended, momentumPhase: [], timestamp: 0.1)
        let r2 = acc.consume(deltaX: 50, deltaY: -10, hasPreciseDeltas: true, phase: .began, momentumPhase: [], timestamp: 0.5)
        #expect(r2 == .previous)
    }

    @Test("鼠标滚轮每格触发一次且 0.25s 内连续滚动合并")
    func wheelCooldown() {
        var acc = PresentationScrollAccumulator()
        let r1 = acc.consume(deltaX: 0, deltaY: -1, hasPreciseDeltas: false, phase: [], momentumPhase: [], timestamp: 10.0)
        #expect(r1 == .next)
        let r2 = acc.consume(deltaX: 0, deltaY: -1, hasPreciseDeltas: false, phase: [], momentumPhase: [], timestamp: 10.1)
        #expect(r2 == nil)
        let r3 = acc.consume(deltaX: 0, deltaY: -1, hasPreciseDeltas: false, phase: [], momentumPhase: [], timestamp: 10.4)
        #expect(r3 == .next)
        let r4 = acc.consume(deltaX: 0, deltaY: 1, hasPreciseDeltas: false, phase: [], momentumPhase: [], timestamp: 11.0)
        #expect(r4 == .previous)
        let r5 = acc.consume(deltaX: 0, deltaY: 0, hasPreciseDeltas: false, phase: [], momentumPhase: [], timestamp: 12.0)
        #expect(r5 == nil)
    }
}

@Suite("PresentationSlideRenderer 屏幕级渲染与预取")
struct PresentationSlideRendererTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("officepeek-present-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cornerRGB(of image: CGImage) throws -> (r: UInt8, g: UInt8, b: UInt8) {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let ctx = CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "PresentationTests", code: 1)
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let offset = (2 * image.width + 2) * 4
        return (pixels[offset], pixels[offset + 1], pixels[offset + 2])
    }

    @Test("show 渲染当前页并预取前后页，尺寸匹配目标像素")
    @MainActor
    func rendersFocusAndNeighbors() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("deck.pptx")
        try TestFixtures.writeMinimalPPTX(to: url, slides: [
            (backgroundHex: "FF0000", title: "One"),
            (backgroundHex: "00FF00", title: "Two"),
            (backgroundHex: "0000FF", title: "Three")
        ])

        let renderer = PresentationSlideRenderer(fileURL: url, targetPixelSize: CGSize(width: 320, height: 180))
        renderer.show(slide: 2)
        await renderer.waitUntilIdle()

        let keys = renderer.images.keys.sorted()
        #expect(keys == [1, 2, 3])
        #expect(renderer.focusSlide == 2)
        #expect(renderer.loadError == nil)

        let second = try #require(renderer.images[2])
        #expect(second.width == 320)
        #expect(second.height == 180)
        let pixel = try cornerRGB(of: second)
        #expect(pixel.g > 200)
        #expect(pixel.r < 50)
    }

    @Test("跳到远端页时淘汰窗口外位图且不渲染越界页")
    @MainActor
    func evictsOutsideRetainWindow() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("five.pptx")
        try TestFixtures.writeMinimalPPTX(to: url, slides: [
            (backgroundHex: "FF0000", title: "1"),
            (backgroundHex: "00FF00", title: "2"),
            (backgroundHex: "0000FF", title: "3"),
            (backgroundHex: "FFFF00", title: "4"),
            (backgroundHex: "00FFFF", title: "5")
        ])

        let renderer = PresentationSlideRenderer(
            fileURL: url,
            targetPixelSize: CGSize(width: 160, height: 90),
            retainRadius: 1
        )
        renderer.show(slide: 1)
        await renderer.waitUntilIdle()
        let firstKeys = renderer.images.keys.sorted()
        #expect(firstKeys == [1, 2])

        renderer.show(slide: 5)
        await renderer.waitUntilIdle()
        let secondKeys = renderer.images.keys.sorted()
        #expect(secondKeys == [4, 5])
    }

    @Test("文档无法解析时给出 loadError")
    @MainActor
    func reportsLoadError() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).pptx")
        let renderer = PresentationSlideRenderer(fileURL: missing, targetPixelSize: CGSize(width: 100, height: 100))
        renderer.show(slide: 1)
        await renderer.waitUntilIdle()
        #expect(renderer.loadError != nil)
        #expect(renderer.images.isEmpty)
    }

    @Test("空 PPTX（0 张幻灯片）时给出 loadError 而不是永久加载")
    @MainActor
    func reportsLoadErrorForEmptyPresentation() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("empty.pptx")
        try TestFixtures.writeMinimalPPTX(to: url, slides: [])

        let renderer = PresentationSlideRenderer(fileURL: url, targetPixelSize: CGSize(width: 160, height: 90))
        renderer.show(slide: 1)
        await renderer.waitUntilIdle()
        #expect(renderer.loadError != nil)
        #expect(renderer.images.isEmpty)
    }
}
