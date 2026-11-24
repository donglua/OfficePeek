import SwiftUI
import AppKit
import OfficePeekKit

/// 演示播放画面：黑底等比居中幻灯片 + 激光点 + 跳页提示 + 黑白遮罩 + 底部 HUD
struct PresentationView: View {
    @ObservedObject var viewModel: PresentationViewModel
    @ObservedObject var renderer: PresentationSlideRenderer

    var body: some View {
        ZStack {
            stage
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.handle(.next)
                }

            if viewModel.isHUDVisible && viewModel.session.blankMode == .none {
                VStack {
                    Spacer()
                    PresentationHUDView(viewModel: viewModel)
                        .padding(.bottom, 36)
                }
                .transition(.opacity)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let location):
                viewModel.pointerMoved(to: location)
            case .ended:
                viewModel.pointerMoved(to: nil)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isHUDVisible)
    }

    private var stage: some View {
        ZStack {
            Color.black
            slideLayer

            if viewModel.session.isLaserEnabled, let point = viewModel.laserPoint {
                LaserDotView()
                    .position(point)
                    .allowsHitTesting(false)
            }

            if !viewModel.session.jumpBuffer.isEmpty {
                Text("跳转到第 \(viewModel.session.jumpBuffer) 页")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .environment(\.colorScheme, .dark)
            }

            switch viewModel.session.blankMode {
            case .black:
                Color.black
            case .white:
                Color.white
            case .none:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var slideLayer: some View {
        let slide = viewModel.session.currentSlide
        if let image = renderer.images[slide] {
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else if renderer.failedSlides.contains(slide) {
            statusText("第 \(slide) 页渲染失败")
        } else if let error = renderer.loadError {
            statusText("无法播放：\(error)")
        } else if let placeholder = viewModel.placeholders[slide] {
            Image(nsImage: placeholder)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fit)
        } else {
            ProgressView()
                .controlSize(.large)
                .environment(\.colorScheme, .dark)
        }
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.white.opacity(0.85))
    }
}

/// 激光笔红点
private struct LaserDotView: View {
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.5))
            .shadow(color: Color.red.opacity(0.9), radius: 10)
            .shadow(color: Color.red.opacity(0.6), radius: 4)
    }
}

/// 底部页码 HUD
private struct PresentationHUDView: View {
    @ObservedObject var viewModel: PresentationViewModel

    var body: some View {
        let session = viewModel.session
        HStack(spacing: 14) {
            hudButton("chevron.left", help: "上一页") {
                viewModel.handle(.previous)
            }
            .disabled(session.currentSlide <= 1)

            Text("\(session.currentSlide) / \(session.slideCount)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 64)

            hudButton("chevron.right", help: "下一页") {
                viewModel.handle(.next)
            }
            .disabled(session.currentSlide >= session.slideCount)

            Divider().frame(height: 18)

            hudButton("cursorarrow.rays", help: "激光笔 (L)", isActive: session.isLaserEnabled) {
                viewModel.handle(.toggleLaser)
            }

            hudButton("xmark", help: "退出演示 (Esc)") {
                viewModel.requestExit()
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.75))
        .environment(\.colorScheme, .dark)
    }

    private func hudButton(
        _ systemImage: String,
        help: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isActive ? .red : .white)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
