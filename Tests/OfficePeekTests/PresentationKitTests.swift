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
