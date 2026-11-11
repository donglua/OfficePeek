import SwiftUI

/// OfficePeek 官方 App Icon 拟物矢量组件（Concept A: 三格式折页透镜）
/// 严格遵循 macOS Human Interface Guidelines 圆角曲率（squircle radius = size * 0.2237）
/// 并支持以任意尺寸矢量平滑缩放。
public struct BrandLogoView: View {
    public let size: CGFloat

    public init(size: CGFloat = 38) {
        self.size = size
    }

    public var body: some View {
        let squircleRadius = size * 0.2237
        let outerBorderWidth = max(0.5, size * 0.02)
        let sheetWidth = size * 0.42
        let sheetHeight = size * 0.54
        let sheetRadius = max(2.0, size * 0.07)
        let sheetBorderWidth = max(0.5, size * 0.018)
        let docxBorderWidth = max(0.75, size * 0.025)
        let lensSize = size * 0.28

        ZStack {
            // 背景底板：深灰/暗夜深空渐变
            RoundedRectangle(cornerRadius: squircleRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.12, blue: 0.18),
                            Color(red: 0.05, green: 0.06, blue: 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 三格式折页图层（PPTX 暖橙 -6°、XLSX 翡翠绿 +6°、DOCX 皇家蓝 居中置顶）
            ZStack {
                // 左下层：PPTX 暖橙色圆角折页，微倾 -6°
                RoundedRectangle(cornerRadius: sheetRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.46, blue: 0.16),
                                Color(red: 0.88, green: 0.30, blue: 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: sheetRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: sheetBorderWidth)
                    )
                    .frame(width: sheetWidth, height: sheetHeight)
                    .rotationEffect(.degrees(-6))
                    .offset(x: -size * 0.095, y: size * 0.025)
                    .shadow(
                        color: Color.black.opacity(0.30),
                        radius: max(1, size * 0.03),
                        x: 0,
                        y: max(0.5, size * 0.015)
                    )

                // 右下层：XLSX 翡翠绿圆角折页，微倾 +6°
                RoundedRectangle(cornerRadius: sheetRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.14, green: 0.70, blue: 0.36),
                                Color(red: 0.08, green: 0.56, blue: 0.26)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: sheetRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: sheetBorderWidth)
                    )
                    .frame(width: sheetWidth, height: sheetHeight)
                    .rotationEffect(.degrees(6))
                    .offset(x: size * 0.095, y: size * 0.025)
                    .shadow(
                        color: Color.black.opacity(0.30),
                        radius: max(1, size * 0.03),
                        x: 0,
                        y: max(0.5, size * 0.015)
                    )

                // 正前层：DOCX 皇家蓝圆角折页，端正居中，带微光白色内描边
                RoundedRectangle(cornerRadius: sheetRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.52, blue: 0.98),
                                Color(red: 0.12, green: 0.38, blue: 0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: sheetRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: docxBorderWidth)
                    )
                    .frame(width: sheetWidth, height: sheetHeight)
                    .offset(x: 0, y: -size * 0.01)
                    .shadow(
                        color: Color.black.opacity(0.35),
                        radius: max(1, size * 0.04),
                        x: 0,
                        y: max(0.5, size * 0.02)
                    )

                // 中心透镜：纯白粗体放大镜 SF Symbol，代表 Office "Peek"
                Image(systemName: "magnifyingglass")
                    .font(.system(size: lensSize, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: 0, y: -size * 0.01)
                    .shadow(
                        color: Color.black.opacity(0.40),
                        radius: max(1, size * 0.025),
                        x: 0,
                        y: max(0.5, size * 0.015)
                    )
            }

            // 外层连续曲率边缘描边（高光倒角质感）
            RoundedRectangle(cornerRadius: squircleRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: outerBorderWidth)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: squircleRadius, style: .continuous))
        .shadow(
            color: Color.black.opacity(0.25),
            radius: max(1, size * 0.06),
            x: 0,
            y: max(0.5, size * 0.03)
        )
        .accessibilityLabel("OfficePeek")
    }
}

#if DEBUG
struct BrandLogoView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            Text("OfficePeek BrandLogoView Scale Previews")
                .font(.headline)

            HStack(spacing: 24) {
                VStack {
                    BrandLogoView(size: 24)
                    Text("24pt").font(.caption).foregroundColor(.secondary)
                }

                VStack {
                    BrandLogoView(size: 38)
                    Text("38pt (Default)").font(.caption).foregroundColor(.secondary)
                }

                VStack {
                    BrandLogoView(size: 64)
                    Text("64pt").font(.caption).foregroundColor(.secondary)
                }

                VStack {
                    BrandLogoView(size: 128)
                    Text("128pt").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(32)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
#endif
