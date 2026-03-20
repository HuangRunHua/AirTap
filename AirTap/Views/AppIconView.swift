import SwiftUI

struct AppIconView: View {
    let app: AppInfo
    let size: CGFloat
    var isEditing: Bool = false
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var showDeleteAlert = false
    @State private var jiggleStart: Date?
    @State private var rotationPhase = Double.random(in: 0 ... .pi * 2)
    @State private var translationPhase = Double.random(in: 0 ... .pi * 2)
    @State private var rotationAmplitude = Double.random(in: 3.0...4.5)
    @State private var translationAmplitude = Double.random(in: 0.8...1.5)
    @State private var speed = Double.random(in: 13...18)
    @State private var isPressed = false

    private var cornerRadius: CGFloat { size * 0.22 }
    private var containerPadding: CGFloat { size * 0.01 }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isEditing)) { timeline in
            let t: Double = {
                guard isEditing, let start = jiggleStart else { return 0 }
                return timeline.date.timeIntervalSince(start)
            }()

            iconContent
                .scaleEffect(isPressed && !isEditing ? 0.88 : 1.0)
                .rotationEffect(.degrees(isEditing ? sin(t * speed + rotationPhase) * rotationAmplitude : 0))
                .offset(
                    x: isEditing ? cos(t * speed * 0.9 + translationPhase) * translationAmplitude : 0,
                    y: isEditing ? sin(t * speed * 1.1 + translationPhase + 1.2) * translationAmplitude : 0
                )
        }
        .onAppear {
            if isEditing && jiggleStart == nil {
                jiggleStart = Date()
            }
        }
        .onChange(of: isEditing) { editing in
            jiggleStart = editing ? Date() : nil
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }) {
            onLongPress?()
        }
        .alert("删除应用", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { onDelete?() }
        } message: {
            Text("确定要从快捷方式中移除「\(app.name)」吗？")
        }
    }

    private var iconContent: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let data = app.iconPNGData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.gray.opacity(0.25))
                            .overlay {
                                Image(systemName: "app.fill")
                                    .font(.system(size: size * 0.45))
                                    .foregroundStyle(.gray)
                            }
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .padding(containerPadding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius + containerPadding * 0.6, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius + containerPadding * 0.6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius + containerPadding * 0.6, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius + containerPadding * 0.6, style: .continuous)
                        .fill(.white.opacity(isPressed && !isEditing ? 0.12 : 0))
                        .allowsHitTesting(false)
                )
                .shadow(color: .white.opacity(isPressed && !isEditing ? 0.25 : 0), radius: 12)

                if isEditing {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(.gray.opacity(0.7)))
                    }
                    .buttonStyle(.plain)
                    .offset(x: -6, y: -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            Text(app.name)
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: size + containerPadding * 2)
        }
    }
}

#Preview("Normal") {
    let mock = AppInfo(bundleID: "com.apple.Safari", name: "Safari", iconPNGData: nil)
    AppIconView(app: mock, size: 80, onTap: {})
        .padding(40)
        .background(Color(red: 0.10, green: 0.08, blue: 0.06))
        .preferredColorScheme(.dark)
}

#Preview("Editing / Jiggle") {
    let mock = AppInfo(bundleID: "com.apple.Safari", name: "Safari", iconPNGData: nil)
    AppIconView(app: mock, size: 80, isEditing: true, onTap: {}, onDelete: {})
        .padding(40)
        .background(Color(red: 0.10, green: 0.08, blue: 0.06))
        .preferredColorScheme(.dark)
}

#Preview("Sizes") {
    let mock = AppInfo(bundleID: "com.apple.Safari", name: "Safari", iconPNGData: nil)
    HStack(spacing: 24) {
        AppIconView(app: mock, size: 60, onTap: {})
        AppIconView(app: mock, size: 80, onTap: {})
        AppIconView(app: mock, size: 100, onTap: {})
    }
    .padding(40)
    .background(Color(red: 0.10, green: 0.08, blue: 0.06))
    .preferredColorScheme(.dark)
}

#Preview("Row - Editing") {
    let apps = ["Safari", "Music", "Photos"].map {
        AppInfo(bundleID: "com.apple.\($0)", name: $0, iconPNGData: nil)
    }
    HStack(spacing: 24) {
        ForEach(apps) { app in
            AppIconView(app: app, size: 80, isEditing: true, onTap: {}, onDelete: {})
        }
    }
    .padding(40)
    .background(Color(red: 0.10, green: 0.08, blue: 0.06))
    .preferredColorScheme(.dark)
}
