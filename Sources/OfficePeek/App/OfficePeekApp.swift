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
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("打开文档…") {
                    appState.pickFileWithPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("返回欢迎主页") {
                    appState.closeDocument()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])

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
