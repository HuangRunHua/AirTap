import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RemoteViewModel()
    @State private var selectedTab = 0
    @State private var manualKeyboard = false
    @State private var landscapeShortcutsExpanded = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool { verticalSizeClass == .compact }
    private var showShortcuts: Bool {
        selectedTab == 1 && viewModel.connection.isConnected && !manualKeyboard
    }

    var body: some View {
        ZStack {
            Group {
                if selectedTab == 0 {
                    AppGridView(viewModel: viewModel)
                } else {
                    TrackpadView(
                        viewModel: viewModel,
                        manualKeyboard: $manualKeyboard,
                        showShortcutBar: false
                    )
                }
            }

            if !manualKeyboard {
                if isLandscape {
                    landscapeOverlay
                } else {
                    portraitOverlay
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { viewModel.connection.startBrowsing() }
    }

    // MARK: - Portrait (bottom, center-aligned)

    private var portraitOverlay: some View {
        VStack(spacing: 8) {
            Spacer()
            if showShortcuts {
                portraitShortcutPill
            }
            portraitTabPill
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .animation(.easeInOut(duration: 0.25), value: showShortcuts)
    }

    private var portraitTabPill: some View {
        HStack(spacing: 6) {
            tabItem(index: 0, icon: "square.grid.2x2.fill", label: "应用")
            tabItem(index: 1, icon: "hand.draw.fill", label: "触控板")
        }
        .padding(6)
        .glassCapsule()
    }

    private var portraitShortcutPill: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                shortcutKeyboardButton
                pillDivider(vertical: true)
                ForEach(ShortcutCommand.allCases, id: \.self) { cmd in
                    shortcutItem(icon: cmd.symbol, label: cmd.shortcutText) {
                        viewModel.sendShortcut(cmd)
                    }
                }
                pillDivider(vertical: true)
                shortcutItem(icon: "speaker.minus.fill", label: "音量−") { viewModel.sendVolumeDown() }
                shortcutItem(icon: "speaker.plus.fill", label: "音量+") { viewModel.sendVolumeUp() }
                shortcutItem(icon: "playpause.fill", label: "播放") { viewModel.sendPlayPause() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .glassCapsule()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Landscape (tab top-right, shortcuts bottom-right collapsible)

    private var landscapeOverlay: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    landscapeTabPill
                }
                .padding(.trailing, 14)
                .padding(.top, 8)
                Spacer()
            }

            if showShortcuts {
                VStack {
                    Spacer()
                    HStack(alignment: .center, spacing: 8) {
                        Spacer()
                        if landscapeShortcutsExpanded {
                            landscapeShortcutPill
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                        landscapeShortcutToggle
                    }
                    .padding(.trailing, 14)
                    .padding(.bottom, 10)
                    .animation(.easeInOut(duration: 0.25), value: landscapeShortcutsExpanded)
                }
            }
        }
    }

    private var landscapeTabPill: some View {
        HStack(spacing: 6) {
            tabItem(index: 0, icon: "square.grid.2x2.fill", label: "应用")
            tabItem(index: 1, icon: "hand.draw.fill", label: "触控板")
        }
        .padding(6)
        .glassCapsule()
    }

    private var landscapeShortcutToggle: some View {
        Button {
            withAnimation { landscapeShortcutsExpanded.toggle() }
        } label: {
            Image(systemName: landscapeShortcutsExpanded ? "xmark" : "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 44, height: 44)
                .background(Capsule().fill(.ultraThinMaterial))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.06)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var landscapeShortcutPill: some View {
        HStack(spacing: 5) {
            shortcutKeyboardButton
            pillDivider(vertical: true)
            ForEach(ShortcutCommand.allCases, id: \.self) { cmd in
                shortcutItem(icon: cmd.symbol, label: cmd.shortcutText) {
                    viewModel.sendShortcut(cmd)
                }
            }
            pillDivider(vertical: true)
            shortcutItem(icon: "speaker.minus.fill", label: "音量−") { viewModel.sendVolumeDown() }
            shortcutItem(icon: "speaker.plus.fill", label: "音量+") { viewModel.sendVolumeUp() }
            shortcutItem(icon: "playpause.fill", label: "播放") { viewModel.sendPlayPause() }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .glassCapsule()
    }

    // MARK: - Tab item

    private func tabItem(index: Int, icon: String, label: String) -> some View {
        let selected = selectedTab == index
        return Button { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index } } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selected ? .white : .white.opacity(0.45))
            .frame(width: 76, height: 54)
            .background {
                if selected {
                    Capsule()
                        .fill(.white.opacity(0.12))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shortcut item

    private func shortcutItem(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 17))
                Text(label).font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 52, height: 44)
            .background(.white.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var shortcutKeyboardButton: some View {
        Button { manualKeyboard = true } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 3) {
                    Image(systemName: "keyboard.fill").font(.system(size: 17))
                    Text("键盘").font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 52, height: 44)
                .background(.white.opacity(0.08))
                .clipShape(Capsule())

                if viewModel.connection.isTextFieldFocused {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                        .offset(x: -3, y: 3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func pillDivider(vertical: Bool) -> some View {
        Group {
            if vertical {
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(.white.opacity(0.15))
                    .frame(width: 1, height: 28)
            } else {
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(.white.opacity(0.15))
                    .frame(width: 36, height: 1)
            }
        }
        .padding(2)
    }
}

// MARK: - Liquid glass background

extension View {
    func glassCapsule() -> some View {
        self
            .background(Capsule().fill(.ultraThinMaterial))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 15, y: 5)
    }
}

#Preview("Tab Bar Only") {
    HStack(spacing: 6) {
        VStack(spacing: 4) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 22, weight: .semibold))
            Text("应用")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.45))
        .frame(width: 76, height: 54)

        VStack(spacing: 4) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 22, weight: .semibold))
            Text("触控板")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.white)
        .frame(width: 76, height: 54)
        .background(Capsule().fill(.white.opacity(0.12)))
    }
    .padding(6)
    .glassCapsule()
    .padding(40)
    .background(Color(red: 0.10, green: 0.08, blue: 0.06))
    .preferredColorScheme(.dark)
}

#Preview("Shortcut Bar Only") {
    HStack(spacing: 5) {
        ForEach(["keyboard.fill", "doc.on.doc", "doc.on.clipboard", "square.on.square", "xmark.square", "arrow.uturn.backward"], id: \.self) { icon in
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 17))
                Text("快捷").font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 52, height: 44)
            .background(.white.opacity(0.08))
            .clipShape(Capsule())
        }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .glassCapsule()
    .padding(20)
    .background(Color(red: 0.10, green: 0.08, blue: 0.06))
    .preferredColorScheme(.dark)
}

#Preview("Full App") {
    ContentView()
}
