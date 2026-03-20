import SwiftUI

struct AppPickerView: View {
    @ObservedObject var viewModel: RemoteViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredApps: [AppInfo] {
        let apps = viewModel.connection.availableApps
        guard !searchText.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(Array(filteredApps.enumerated()), id: \.offset) { _, app in
                HStack(spacing: 12) {
                    if let data = app.iconPNGData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(.gray.opacity(0.2))
                            .frame(width: 40, height: 40)
                    }

                    VStack(alignment: .leading) {
                        Text(app.name)
                        Text(app.bundleID)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        viewModel.addApp(app)
                        dismiss()
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "搜索应用")
            .navigationTitle("添加应用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
