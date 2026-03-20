import SwiftUI

struct ShortcutBarView: View {
    @ObservedObject var viewModel: RemoteViewModel
    @Binding var showKeyboard: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                keyboardButton

                divider

                ForEach(ShortcutCommand.allCases, id: \.self) { cmd in
                    shortcutButton(title: cmd.shortcutText, icon: cmd.symbol) {
                        viewModel.sendShortcut(cmd)
                    }
                }

                divider

                shortcutButton(title: "音量−", icon: "speaker.minus.fill") { viewModel.sendVolumeDown() }
                shortcutButton(title: "音量+", icon: "speaker.plus.fill")  { viewModel.sendVolumeUp() }
                shortcutButton(title: "播放",  icon: "playpause.fill")     { viewModel.sendPlayPause() }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Components

    private var keyboardButton: some View {
        Button { showKeyboard.toggle() } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 3) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 16))
                    Text("键盘")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.white)
                .frame(width: 52, height: 44)
                .background(.white.opacity(showKeyboard ? 0.2 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if viewModel.connection.isTextFieldFocused {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                        .offset(x: -4, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Divider().frame(height: 28).padding(.horizontal, 2)
    }

    private func shortcutButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 9))
            }
            .foregroundStyle(.white)
            .frame(width: 52, height: 44)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
