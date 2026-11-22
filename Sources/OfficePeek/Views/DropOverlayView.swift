import SwiftUI
import UniformTypeIdentifiers
import JZOffice

/// 全窗口毛玻璃拖拽浮层：在拖入 Office 文档经过窗口任意位置时柔和浮现
struct DropOverlayView: View {
    let isTargeted: Bool

    var body: some View {
        ZStack {
            if isTargeted {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: ThemeSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: ThemeRadius.large, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 56, height: 56)

                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }

                    VStack(spacing: ThemeSpacing.xs) {
                        Text("松手以预览文档")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("支持 .docx / .pptx / .xlsx · 毫秒级离线原生矢量渲染")
                            .font(ThemeTypography.bodySecondary)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: ThemeSpacing.sm) {
                        FormatBadgeView(kind: .docx, compact: true)
                        FormatBadgeView(kind: .pptx, compact: true)
                        FormatBadgeView(kind: .xlsx, compact: true)
                    }
                    .padding(.top, ThemeSpacing.xxs)
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 28)
                .background(
                    RoundedRectangle(cornerRadius: ThemeRadius.extraLarge, style: .continuous)
                        .fill(ThemeColor.cardBackground.opacity(0.95))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeRadius.extraLarge, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.65), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isTargeted)
    }

    /// 从拖拽提供的 NSItemProvider 列表中提取首个本地文件 URL
    static func extractFirstFileURL(
        from providers: [NSItemProvider],
        onResolved: @escaping @MainActor (URL) -> Void
    ) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let targetURL: URL?
            if let url = item as? URL {
                targetURL = url
            } else if let nsURL = item as? NSURL {
                targetURL = nsURL as URL
            } else if let data = item as? Data {
                targetURL = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                targetURL = nil
            }
            guard let url = targetURL else { return }
            Task { @MainActor in
                onResolved(url)
            }
        }
        return true
    }
}
