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
                Task { @MainActor in
                    AppState.shared.openDocument(at: url)
                }
                break
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        Task { @MainActor in
            AppState.shared.openDocument(at: first)
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
                .disabled(appState.activeFileURL == nil)

                Button("导出当前页为高清 PNG…") {
                    appState.exportCurrentPagePNG()
                }
                .disabled(appState.activeFileURL == nil)
            }

            CommandGroup(after: .sidebar) {
                Button(appState.isSidebarVisible ? "隐藏侧边栏" : "显示侧边栏") {
                    withAnimation {
                        appState.isSidebarVisible.toggle()
                    }
                }
                .keyboardShortcut("\\", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)
            }

            CommandMenu("查找与导航") {
                Button("在文档中查找…") {
                    appState.previewController.presentSearch()
                }
                .keyboardShortcut("f", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)

                Button("查找下一个") {
                    appState.previewController.findNext()
                }
                .keyboardShortcut("g", modifiers: [.command])
                .disabled(appState.activeFileURL == nil || !appState.previewController.isSearchPresented)

                Button("查找上一个") {
                    appState.previewController.findPrevious()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(appState.activeFileURL == nil || !appState.previewController.isSearchPresented)

                Button("关闭查找栏") {
                    appState.previewController.dismissSearch()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(appState.activeFileURL == nil || !appState.previewController.isSearchPresented)

                Divider()

                Button("上一页 / 工作表") {
                    appState.previewController.jumpToPage(max(1, appState.previewController.currentPage - 1))
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
                .disabled(appState.activeFileURL == nil || appState.previewController.currentPage <= 1)

                Button("下一页 / 工作表") {
                    appState.previewController.jumpToPage(min(appState.previewController.pageCount, appState.previewController.currentPage + 1))
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])
                .disabled(appState.activeFileURL == nil || appState.previewController.currentPage >= appState.previewController.pageCount)
            }

            CommandMenu("视图") {
                Button("放大") {
                    appState.previewController.setZoom(appState.previewController.zoom + 0.25)
                }
                .keyboardShortcut("=", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)

                Button("缩小") {
                    appState.previewController.setZoom(appState.previewController.zoom - 0.25)
                }
                .keyboardShortcut("-", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)

                Button("实际大小 (100%)") {
                    appState.previewController.resetZoom()
                }
                .keyboardShortcut("0", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)
            }

            TextEditingCommands()
        }
    }
}

struct RootContainerView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            if let fileURL = appState.activeFileURL {
                DocumentReaderView(
                    fileURL: fileURL,
                    appState: appState,
                    controller: appState.previewController,
                    pageThumbnailCache: appState.pageThumbnailCache
                )
            } else {
                WelcomeView(
                    appState: appState,
                    recentStore: appState.recentStore
                )
            }

            if let toast = appState.toastMessage {
                Text(toast)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                    )
                    .padding(.bottom, 18)
            }
        }
    }
}
