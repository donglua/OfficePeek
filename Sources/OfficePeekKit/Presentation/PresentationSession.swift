import Foundation

/// 演示黑/白屏状态
public enum PresentationBlankMode: Equatable, Sendable {
    case none
    case black
    case white
}

/// 演示模式输入命令（键盘、鼠标、触控板与 HUD 统一转换为命令）
public enum PresentationCommand: Equatable, Sendable {
    case next
    case previous
    case first
    case last
    case goTo(Int)
    case digit(Int)
    case commitJump
    case cancel
    case toggleBlack
    case toggleWhite
    case toggleLaser
}

/// 命令执行后的副作用
public enum PresentationEffect: Equatable, Sendable {
    case none
    case exit
}

/// 演示会话状态机（唯一状态源，UI 层不再自行判断翻页/黑屏/跳页规则）
public struct PresentationSession: Equatable, Sendable {
    public static let maxJumpDigits = 4

    public let slideCount: Int
    public private(set) var currentSlide: Int
    public private(set) var blankMode: PresentationBlankMode = .none
    public private(set) var jumpBuffer: String = ""
    public private(set) var isLaserEnabled: Bool = false

    public init(slideCount: Int, startSlide: Int) {
        let count = max(1, slideCount)
        self.slideCount = count
        self.currentSlide = min(max(1, startSlide), count)
    }

    @discardableResult
    public mutating func apply(_ command: PresentationCommand) -> PresentationEffect {
        switch command {
        case .cancel:
            if !jumpBuffer.isEmpty {
                jumpBuffer = ""
                return .none
            }
            if blankMode != .none {
                blankMode = .none
                return .none
            }
            return .exit

        case .digit(let value):
            guard (0...9).contains(value), jumpBuffer.count < Self.maxJumpDigits else {
                return .none
            }
            jumpBuffer.append(String(value))
            return .none

        case .commitJump:
            if jumpBuffer.isEmpty {
                return apply(.next)
            }
            let target = Int(jumpBuffer) ?? 0
            jumpBuffer = ""
            if target >= 1 {
                blankMode = .none
                currentSlide = min(target, slideCount)
            }
            return .none

        case .toggleBlack:
            blankMode = blankMode == .black ? .none : .black
            return .none

        case .toggleWhite:
            blankMode = blankMode == .white ? .none : .white
            return .none

        case .toggleLaser:
            isLaserEnabled.toggle()
            return .none

        case .next, .previous, .first, .last, .goTo:
            jumpBuffer = ""
            if blankMode != .none {
                blankMode = .none
                return .none
            }
            navigate(command)
            return .none
        }
    }

    private mutating func navigate(_ command: PresentationCommand) {
        switch command {
        case .next:
            currentSlide = min(slideCount, currentSlide + 1)
        case .previous:
            currentSlide = max(1, currentSlide - 1)
        case .first:
            currentSlide = 1
        case .last:
            currentSlide = slideCount
        case .goTo(let target):
            currentSlide = min(max(1, target), slideCount)
        default:
            break
        }
    }
}

/// 演示起始位置
public enum PresentationStart: Equatable, Sendable {
    case beginning
    case currentSlide

    /// 计算起始页（1 起），`currentPage` 为 0（尚未加载）时视为第 1 页
    public func startSlide(currentPage: Int, slideCount: Int) -> Int {
        let count = max(1, slideCount)
        switch self {
        case .beginning:
            return 1
        case .currentSlide:
            return min(max(1, currentPage), count)
        }
    }
}
