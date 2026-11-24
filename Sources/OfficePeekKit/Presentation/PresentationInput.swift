import AppKit

/// 演示模式键盘映射（方向/功能键按虚拟键码匹配，字母/数字/标点按字符匹配）
public enum PresentationKeyMap {
    public enum KeyCode {
        public static let returnKey: UInt16 = 36
        public static let space: UInt16 = 49
        public static let delete: UInt16 = 51
        public static let escape: UInt16 = 53
        public static let keypadEnter: UInt16 = 76
        public static let home: UInt16 = 115
        public static let pageUp: UInt16 = 116
        public static let end: UInt16 = 119
        public static let pageDown: UInt16 = 121
        public static let leftArrow: UInt16 = 123
        public static let rightArrow: UInt16 = 124
        public static let downArrow: UInt16 = 125
        public static let upArrow: UInt16 = 126
    }

    /// 返回 `nil` 表示该按键不由演示模式处理，应原样交给系统（如 ⌘Q、⌘W）
    public static func command(
        keyCode: UInt16,
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags
    ) -> PresentationCommand? {
        let passThrough: NSEvent.ModifierFlags = [.command, .control, .option]
        guard modifierFlags.intersection(passThrough).isEmpty else { return nil }

        switch keyCode {
        case KeyCode.rightArrow, KeyCode.downArrow, KeyCode.space, KeyCode.pageDown:
            return .next
        case KeyCode.leftArrow, KeyCode.upArrow, KeyCode.delete, KeyCode.pageUp:
            return .previous
        case KeyCode.returnKey, KeyCode.keypadEnter:
            return .commitJump
        case KeyCode.home:
            return .first
        case KeyCode.end:
            return .last
        case KeyCode.escape:
            return .cancel
        default:
            break
        }

        guard let text = charactersIgnoringModifiers?.lowercased(),
              text.count == 1,
              let character = text.first else {
            return nil
        }
        if character.isASCII, let digit = character.wholeNumberValue {
            return .digit(digit)
        }
        switch character {
        case "n":
            return .next
        case "p":
            return .previous
        case "b", ".":
            return .toggleBlack
        case "w", ",":
            return .toggleWhite
        case "l":
            return .toggleLaser
        default:
            return nil
        }
    }
}

/// 将滚轮与触控板滑动转换为翻页命令：
/// - 触控板（precise）：同一手势累计位移超过阈值触发一次，手势结束前不再触发；惯性阶段忽略
/// - 鼠标滚轮：每次非零滚动触发一次，冷却时间内的连续滚动合并
/// - 主轴取 |deltaY| 与 |deltaX| 较大者；delta < 0（内容向上/向左移动）→ 下一页
public struct PresentationScrollAccumulator: Sendable {
    public static let preciseThreshold: CGFloat = 40
    public static let wheelCooldown: TimeInterval = 0.25

    private var accumulated: CGFloat = 0
    private var hasFiredInGesture = false
    private var lastWheelFire: TimeInterval = -.greatestFiniteMagnitude

    public init() {}

    public mutating func consume(
        deltaX: CGFloat,
        deltaY: CGFloat,
        hasPreciseDeltas: Bool,
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase,
        timestamp: TimeInterval
    ) -> PresentationCommand? {
        guard momentumPhase.isEmpty else { return nil }
        let primary = abs(deltaY) >= abs(deltaX) ? deltaY : deltaX

        if hasPreciseDeltas {
            if phase.contains(.began) || phase.contains(.mayBegin) {
                accumulated = 0
                hasFiredInGesture = false
            }
            defer {
                if phase.contains(.ended) || phase.contains(.cancelled) {
                    accumulated = 0
                    hasFiredInGesture = false
                }
            }
            guard !hasFiredInGesture else { return nil }
            accumulated += primary
            guard abs(accumulated) >= Self.preciseThreshold else { return nil }
            hasFiredInGesture = true
            return Self.command(for: accumulated)
        }

        guard primary != 0, timestamp - lastWheelFire >= Self.wheelCooldown else { return nil }
        lastWheelFire = timestamp
        return Self.command(for: primary)
    }

    private static func command(for delta: CGFloat) -> PresentationCommand {
        delta < 0 ? .next : .previous
    }
}
