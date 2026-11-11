import Testing
import SwiftUI
import JZOffice
@testable import OfficePeek

@Suite("Theme Design Tokens 测试")
struct ThemeTests {

    @Test("ThemeColor 格式专用色与微调色值对齐设计规范")
    func formatColors() {
        let expectedDocx = Color(red: 0.16, green: 0.44, blue: 0.96)
        let expectedPptx = Color(red: 0.94, green: 0.38, blue: 0.12)
        let expectedXlsx = Color(red: 0.10, green: 0.65, blue: 0.34)

        #expect(ThemeColor.docxPrimary == expectedDocx)
        #expect(ThemeColor.pptxPrimary == expectedPptx)
        #expect(ThemeColor.xlsxPrimary == expectedXlsx)

        #expect(ThemeColor.color(for: .docx) == expectedDocx)
        #expect(ThemeColor.color(for: .pptx) == expectedPptx)
        #expect(ThemeColor.color(for: .xlsx) == expectedXlsx)

        #expect(ThemeColor.tint(for: .docx) == ThemeColor.docxTint)
        #expect(ThemeColor.tint(for: .pptx) == ThemeColor.pptxTint)
        #expect(ThemeColor.tint(for: .xlsx) == ThemeColor.xlsxTint)

        _ = ThemeColor.subtleBorder
        _ = ThemeColor.subtleBorderDark
    }

    @Test("ThemeTypography 字阶完整性")
    func typographyTokens() {
        _ = ThemeTypography.heroTitle
        _ = ThemeTypography.windowTitle
        _ = ThemeTypography.sectionHeader
        _ = ThemeTypography.bodyPrimary
        _ = ThemeTypography.bodySecondary
        _ = ThemeTypography.captionBadge
        _ = ThemeTypography.monospacedValue
    }

    @Test("ThemeSpacing 与 ThemeRadius 间距和圆角数值满足排版阶梯")
    func spacingAndRadiusTokens() {
        #expect(ThemeSpacing.xxs == 2)
        #expect(ThemeSpacing.xs == 4)
        #expect(ThemeSpacing.sm == 8)
        #expect(ThemeSpacing.md == 12)
        #expect(ThemeSpacing.lg == 16)
        #expect(ThemeSpacing.xl == 24)
        #expect(ThemeSpacing.xxl == 32)

        #expect(ThemeRadius.small == 6)
        #expect(ThemeRadius.medium == 10)
        #expect(ThemeRadius.large == 14)
        #expect(ThemeRadius.squircle == 18)
    }
}
