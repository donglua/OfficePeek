#!/usr/bin/env swift
import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - BrandLogoView Definition

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

// MARK: - Helper Functions

func savePNG(cgImage: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "generate-icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImageDestination for \(url.path)"])
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "generate-icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG for \(url.path)"])
    }
}

// MARK: - Main Generation Logic

MainActor.assumeIsolated {
    let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
    let rootURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()

    let outputPath: String
    if CommandLine.arguments.count > 1 {
        outputPath = CommandLine.arguments[1]
    } else {
        outputPath = rootURL.appendingPathComponent("Resources/AppIcon.icns").path
    }
    let outputURL = URL(fileURLWithPath: outputPath)

    print("==> OfficePeek AppIcon Generator")
    print("    Target icns: \(outputURL.path)")

    // 1. Render distinct sizes
    let distinctSizes = [16, 32, 64, 128, 256, 512, 1024]
    var renderedImages: [Int: CGImage] = [:]

    for size in distinctSizes {
        let view = BrandLogoView(size: CGFloat(size))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        guard let cgImage = renderer.cgImage else {
            fatalError("Failed to render BrandLogoView at size \(size)x\(size)")
        }
        renderedImages[size] = cgImage
        print("    [✓] Rendered BrandLogoView @ \(size)x\(size)")
    }

    // 2. Prepare temporary .iconset directory
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
    try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    let iconSpecs: [(name: String, size: Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    for spec in iconSpecs {
        guard let cgImage = renderedImages[spec.size] else {
            fatalError("Missing rendered image for size \(spec.size)")
        }
        let fileURL = tempDir.appendingPathComponent(spec.name)
        try! savePNG(cgImage: cgImage, to: fileURL)
    }
    print("    [✓] Exported 10 iconset images to \(tempDir.path)")

    // 3. Ensure destination directory exists
    let destDir = outputURL.deletingLastPathComponent()
    try! FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

    // 4. Run iconutil to create .icns
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", tempDir.path, "-o", outputURL.path]

    let pipe = Pipe()
    process.standardError = pipe
    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: data, encoding: .utf8) ?? ""
            fatalError("iconutil failed with code \(process.terminationStatus): \(errStr)")
        }
    } catch {
        fatalError("Failed to execute iconutil: \(error)")
    }

    // 5. Verify output file
    if FileManager.default.fileExists(atPath: outputURL.path),
       let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
       let size = attrs[.size] as? Int64 {
        let sizeFormatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        print("==> Successfully generated AppIcon.icns (\(sizeFormatted)) at:")
        print("    \(outputURL.path)")
    } else {
        fatalError("Generated icns file not found at \(outputURL.path)")
    }
}
