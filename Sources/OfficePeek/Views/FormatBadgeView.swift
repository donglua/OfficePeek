import SwiftUI
import JZOffice

/// DOCX / PPTX / XLSX 彩色格式徽章
struct FormatBadgeView: View {
    let kind: OfficeKind
    var compact: Bool = false

    private var badgeColor: Color {
        switch kind {
        case .docx:
            return Color(red: 0.15, green: 0.39, blue: 0.92)
        case .pptx:
            return Color(red: 0.92, green: 0.35, blue: 0.05)
        case .xlsx:
            return Color(red: 0.09, green: 0.64, blue: 0.29)
        }
    }

    var body: some View {
        Text(kind.rawValue)
            .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 2 : 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(badgeColor)
            )
    }
}
