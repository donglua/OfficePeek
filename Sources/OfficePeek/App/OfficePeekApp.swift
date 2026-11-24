import SwiftUI
import AppKit
import OfficePeekKit

final class OfficePeekAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true
        let args = CommandLine.arguments.dropFirst()
        for arg in args where !arg.hasPrefix("-") {
            let url = URL(fileURLWithPath: arg)
            if FileManager.default.fileExists(atPath: url.path) {
                openOnMainActor(url)
                break
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        openOnMainActor(first)
    }

    private func openOnMainActor(_ url: URL) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                AppState.shared.openDocument(at: url)
            }
        } else {
            Task { @MainActor in
                AppState.shared.openDocument(at: url)
            }
        }
    }
}

@main
struct OfficePeekApp: App {
    @NSApplicationDelegateAdaptor(OfficePeekAppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup("OfficePeek") {
            RootContainerView(appState: appState)
                .frame(minWidth: 920, minHeight: 640)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("打开文档…") {
                    appState.pickFileWithPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])
                .disabled(appState.isPresenting)

                Button("返回欢迎主页") {
                    appState.closeDocument()
                }
                .keyboardShortcut("w", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)

                Divider()

                Button("导出为矢量 PDF…") {
                    appState.exportPDF()
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(appState.activeFileURL == nil || appState.isPresenting)

                Button("导出当前页为高清 PNG…") {
                    appState.exportCurrentPagePNG()
                }
                .disabled(appState.activeFileURL == nil || appState.isPresenting)
            }

            CommandGroup(after: .sidebar) {
                Button(appState.isSidebarVisible ? "隐藏侧边栏" : "显示侧边栏") {
                    withAnimation {
                        appState.isSidebarVisible.toggle()
                    }
                }
                .keyboardShortcut("\\", modifiers: [.command])
                .disabled(appState.activeFileURL == nil || appState.isPresenting)
            }

            CommandMenu("查找与导航") {
                Button("在文档中查找…") {
                    appState.presentSearch()
                }
                .keyboardShortcut("f", modifiers: [.command])
                .disabled(appState.activeFileURL == nil || appState.isPresenting)

                Button("查找下一个") {
                    appState.previewController.findNext()
                }
                .keyboardShortcut("g", modifiers: [.command])
                .disabled(appState.activeFileURL == nil || !appState.previewController.isSearchPresented || appState.isPresenting)

                Button("查找上一个") {
                    appState.previewController.findPrevious()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(appState.activeFileURL == nil || !appState.previewController.isSearchPresented || appState.isPresenting)

                Button("关闭查找栏") {
                    appState.previewController.dismissSearch()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(appState.activeFileURL == nil || !appState.previewController.isSearchPresented || appState.isPresenting)

                Divider()

                Button("上一页 / 工作表") {
                    appState.previewController.jumpToPage(max(1, appState.previewController.currentPage - 1))
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
                .disabled(appState.activeFileURL == nil || appState.previewController.currentPage <= 1 || appState.isPresenting)

                Button("下一页 / 工作表") {
                    appState.previewController.jumpToPage(min(appState.previewController.pageCount, appState.previewController.currentPage + 1))
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])
                .disabled(appState.activeFileURL == nil || appState.previewController.currentPage >= appState.previewController.pageCount || appState.isPresenting)
            }

            CommandMenu("播放") {
                Button("从头开始播放") {
                    appState.startPresentation(.beginning)
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(!appState.canStartPresentation)

                Button("从当前幻灯片播放") {
                    appState.startPresentation(.currentSlide)
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!appState.canStartPresentation)
            }

            CommandMenu("视图") {
                Button("放大") {
                    appState.previewController.setZoom(appState.previewController.zoom + 0.25)
                }
                .keyboardShortcut("=", modifiers: [.command])
                .disabled(appState.activeFileURL == nil || appState.isPresenting)

                Button("缩小") {
                    appState.previewController.setZoom(appState.previewController.zoom - 0.25)
                }
                .keyboardShortcut("-", modifiers: [.command])
                .disabled(appState.activeFileURL == nil || appState.isPresenting)

                Button("实际大小 (100%)") {
                    appState.previewController.resetZoom()
                }
                .keyboardShortcut("0", modifiers: [.command])
                .disabled(appState.activeFileURL == nil || appState.isPresenting)
            }

            TextEditingCommands()
        }
    }
}

struct RootContainerView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let fileURL = appState.activeFileURL {
                    DocumentReaderView(
                        fileURL: fileURL,
                        appState: appState,
                        controller: appState.previewController,
                        pageThumbnailCache: appState.pageThumbnailCache
                    )
                    .transition(.opacity)
                } else {
                    WelcomeView(
                        appState: appState,
                        recentStore: appState.recentStore
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: appState.activeFileURL)

            if let toast = appState.toastMessage {
                ToastBannerView(message: toast)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: appState.toastMessage)
    }
}

private struct ToastBannerView: View {
    let message: String

    private var iconName: String {
        if message.contains("失败") || message.contains("不存在") {
            return "exclamationmark.triangle.fill"
        }
        if message.contains("已导出") {
            return "checkmark.circle.fill"
        }
        return "info.circle.fill"
    }

    private var iconColor: Color {
        if message.contains("失败") || message.contains("不存在") {
            return .orange
        }
        if message.contains("已导出") {
            return .green
        }
        return .accentColor
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(iconColor)

            Text(message)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(.regularMaterial)
        )
        .overlay(
            Capsule()
                .strokeBorder(ThemeColor.subtleBorder, lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 5)
    }
}
