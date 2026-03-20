import SwiftUI

struct ConnectionView: View {
    @ObservedObject var viewModel: RemoteViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "desktopcomputer")
                .font(.system(size: 64))
                .foregroundStyle(.gray)

            if viewModel.connection.isSearching {
                ProgressView()
                    .scaleEffect(1.2)
                Text("正在搜索 Mac…")
                    .foregroundStyle(.secondary)
            } else {
                Text("未连接到 Mac")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("请确保 Mac 端已运行 AirTap")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Button("搜索连接") {
                    viewModel.connection.startBrowsing()
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
