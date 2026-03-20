import SwiftUI

struct AppGridView: View {
    @ObservedObject var viewModel: RemoteViewModel
    @State private var showingPicker = false
    @State private var isEditing = false
    @State private var currentPage = 0
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool { verticalSizeClass == .compact }

    private var totalDisplayCount: Int {
        viewModel.selectedApps.count + 1
    }

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.08, blue: 0.06)
                .ignoresSafeArea()
                .onTapGesture {
                    if isEditing { withAnimation { isEditing = false } }
                }

            if !viewModel.connection.isConnected {
                ConnectionView(viewModel: viewModel)
            } else {
                VStack(spacing: 0) {
                    if let name = viewModel.connection.macName {
                        HStack {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.leading, 20)
                            Spacer()
                        }
                        .padding(.top, 12)
                        .onTapGesture {
                            if isEditing { withAnimation { isEditing = false } }
                        }
                    }

                    GeometryReader { geo in
                        let layout = GridLayout(size: geo.size)
                        let pageCount = layout.pageCount(total: totalDisplayCount)

                        TabView(selection: $currentPage) {
                            ForEach(0..<pageCount, id: \.self) { page in
                                buildPage(layout: layout, page: page)
                                    .tag(page)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }

                    if totalDisplayCount > GridLayout.defaultItemsPerPage {
                        pageIndicator(
                            count: max(1, (totalDisplayCount + GridLayout.defaultItemsPerPage - 1) / GridLayout.defaultItemsPerPage),
                            current: currentPage
                        )
                        .padding(.vertical, 10)
                    }

                    if !isLandscape {
                        Spacer().frame(height: 80)
                    }
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            AppPickerView(viewModel: viewModel)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func buildPage(layout: GridLayout, page: Int) -> some View {
        let startIndex = page * layout.itemsPerPage
        let endIndex = min(startIndex + layout.itemsPerPage, totalDisplayCount)

        VStack(spacing: layout.verticalSpacing) {
            ForEach(0..<layout.rows, id: \.self) { row in
                HStack(spacing: layout.horizontalSpacing) {
                    ForEach(0..<layout.columns, id: \.self) { col in
                        let slotIndex = startIndex + row * layout.columns + col
                        if slotIndex < endIndex {
                            if slotIndex < viewModel.selectedApps.count {
                                let app = viewModel.selectedApps[slotIndex]
                                AppIconView(
                                    app: app,
                                    size: layout.iconSize,
                                    isEditing: isEditing,
                                    onTap: { viewModel.launchApp(app) },
                                    onLongPress: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isEditing = true
                                        }
                                    },
                                    onDelete: {
                                        withAnimation {
                                            viewModel.removeApp(at: slotIndex)
                                        }
                                    }
                                )
                            } else {
                                addButton(size: layout.iconSize)
                            }
                        } else {
                            Color.clear
                                .frame(width: layout.iconSize, height: layout.iconSize + 20)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isEditing { withAnimation { isEditing = false } }
                                }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addButton(size: CGFloat) -> some View {
        let cr = size * 0.22
        let cp = size * 0.01
        return Button {
            showingPicker = true
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: size * 0.35, weight: .light))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(width: size, height: size)
                    .padding(cp)
                    .background(
                        RoundedRectangle(cornerRadius: cr + cp * 0.6, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cr + cp * 0.6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cr + cp * 0.6, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.15), .white.opacity(0.03)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )

                Text("添加")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
                    .frame(width: size)
            }
        }
        .buttonStyle(.plain)
    }

    private func pageIndicator(count: Int, current: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? .white : .white.opacity(0.3))
                    .frame(width: 7, height: 7)
                    .scaleEffect(index == current ? 1.0 : 0.85)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}

// MARK: - Layout calculator

struct GridLayout {
    let columns: Int
    let rows: Int
    let iconSize: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    static let defaultItemsPerPage = 8

    init(size: CGSize) {
        let isLandscape = size.width > size.height
        columns = isLandscape ? 4 : 2
        rows    = isLandscape ? 2 : 4
        horizontalSpacing = isLandscape ? 32 : 32
        verticalSpacing   = isLandscape ? 16 : 20

        let labelHeight: CGFloat = 22
        let hPad: CGFloat = isLandscape ? 60 : 48
        let vPad: CGFloat = isLandscape ? 24 : 32
        let maxW = (size.width - hPad - CGFloat(columns - 1) * horizontalSpacing) / CGFloat(columns)
        let maxH = (size.height - vPad - CGFloat(rows) * (verticalSpacing + labelHeight)) / CGFloat(rows)
        iconSize = min(maxW, maxH, 120)
    }

    var itemsPerPage: Int { columns * rows }

    func pageCount(total: Int) -> Int {
        max(1, (total + itemsPerPage - 1) / itemsPerPage)
    }

    func items<T>(forPage page: Int, from array: [T]) -> [T] {
        let start = page * itemsPerPage
        let end = min(start + itemsPerPage, array.count)
        guard start < array.count else { return [] }
        return Array(array[start..<end])
    }
}

// MARK: - Previews

private struct GridPreviewWrapper: View {
    let apps: [AppInfo]
    @State private var isEditing = false
    @State private var showPicker = false
    @State private var items: [AppInfo]

    init(apps: [AppInfo]) {
        self.apps = apps
        _items = State(initialValue: apps)
    }

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.08, blue: 0.06).ignoresSafeArea()
                .onTapGesture { withAnimation { isEditing = false } }

            let layout = GridLayout(size: CGSize(width: 393, height: 600))
            VStack(spacing: layout.verticalSpacing) {
                ForEach(0..<layout.rows, id: \.self) { row in
                    HStack(spacing: layout.horizontalSpacing) {
                        ForEach(0..<layout.columns, id: \.self) { col in
                            let idx = row * layout.columns + col
                            if idx < items.count {
                                AppIconView(
                                    app: items[idx],
                                    size: layout.iconSize,
                                    isEditing: isEditing,
                                    onTap: {},
                                    onLongPress: { withAnimation { isEditing = true } },
                                    onDelete: { items.remove(at: idx) }
                                )
                            } else if idx == items.count {
                                addPlaceholder(size: layout.iconSize)
                            }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func addPlaceholder(size: CGFloat) -> some View {
        let cr = size * 0.22
        return VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: size * 0.35, weight: .light))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(width: size, height: size)
            Text("添加").font(.caption2).foregroundStyle(.white.opacity(0.4))
        }
    }
}

#Preview("Grid - Few Apps") {
    let apps = ["Safari", "Music", "Photos", "Mail", "Notes"].map {
        AppInfo(bundleID: "com.apple.\($0)", name: $0, iconPNGData: nil)
    }
    GridPreviewWrapper(apps: apps)
}

#Preview("Grid - Full Page") {
    let names = ["Safari", "Music", "Photos", "Mail", "Notes", "Calendar",
                 "Maps", "Weather", "Clock", "Calculator", "Settings"]
    let apps = names.map { AppInfo(bundleID: "com.apple.\($0)", name: $0, iconPNGData: nil) }
    GridPreviewWrapper(apps: apps)
}

#Preview("Grid - Empty") {
    GridPreviewWrapper(apps: [])
}
