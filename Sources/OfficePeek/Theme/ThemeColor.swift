import SwiftUI
import JZOffice

public enum ThemeColor {
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
}
