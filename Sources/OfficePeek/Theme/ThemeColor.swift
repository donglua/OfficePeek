import SwiftUI
import JZOffice

public enum ThemeColor {
    /// 应用品牌色：低饱和靛蓝，兼顾浅色与深色外观。
    public static let brandPrimary = Color(red: 0.35, green: 0.39, blue: 0.91)
    public static let brandSecondary = Color(red: 0.50, green: 0.45, blue: 0.92)

    public static let windowBackground = Color(nsColor: .windowBackgroundColor)
    public static let canvasBackground = Color(nsColor: .underPageBackgroundColor)
    public static let cardBackground = Color(nsColor: .controlBackgroundColor)
    public static let insetBackground = Color.primary.opacity(0.035)
    public static let hoverBackground = Color.primary.opacity(0.055)

    public static let docxPrimary = Color(red: 0.16, green: 0.44, blue: 0.96)
    public static let docxTint = Color.blue.opacity(0.12)

    public static let pptxPrimary = Color(red: 0.94, green: 0.38, blue: 0.12)
    public static let pptxTint = Color.orange.opacity(0.12)

    public static let xlsxPrimary = Color(red: 0.10, green: 0.65, blue: 0.34)
    public static let xlsxTint = Color.green.opacity(0.12)

    public static func color(for kind: OfficeKind) -> Color {
        switch kind {
        case .docx: return docxPrimary
        case .pptx: return pptxPrimary
        case .xlsx: return xlsxPrimary
        }
    }

    public static func tint(for kind: OfficeKind) -> Color {
        switch kind {
        case .docx: return docxTint
        case .pptx: return pptxTint
        case .xlsx: return xlsxTint
        }
    }

    public static let subtleBorder = Color.primary.opacity(0.08)
    public static let subtleBorderDark = Color.white.opacity(0.10)
    public static let thumbnailStageBackground = Color(nsColor: .underPageBackgroundColor).opacity(0.75)
    public static let segmentedTrackBackground = Color.primary.opacity(0.055)
    public static let segmentedPillBackground = Color(nsColor: .controlBackgroundColor)
    public static let elevatedBorder = Color.accentColor.opacity(0.38)
    public static let hairlineSeparator = Color.primary.opacity(0.07)
    public static let skeletonFill = Color.primary.opacity(0.07)
}
