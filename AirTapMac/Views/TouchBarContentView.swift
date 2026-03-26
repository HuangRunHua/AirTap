import SwiftUI

struct TouchBarContentView: View {
    let appName: String
    let items: [ActionItem]
    let onAction: (ActionItem, Double?) -> Void

    @State private var hoveredID: String?
    @State private var toggleStates: [String: Bool] = [:]
    @State private var sliderValues: [String: Double] = [:]

    var body: some View {
        HStack(spacing: 0) {
            appLabel
            divider

            HStack(spacing: 4) {
                ForEach(items) { item in
                    itemView(for: item)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
    }

    // MARK: - App label

    private var appLabel: some View {
        Text(appName)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.trailing, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 28)
            .padding(.trailing, 8)
    }

    // MARK: - Item dispatch

    @ViewBuilder
    private func itemView(for item: ActionItem) -> some View {
        switch item.type {
        case .button:
            buttonView(for: item)
        case .slider:
            sliderView(for: item)
        case .toggle:
            toggleView(for: item)
        case .segmented:
            buttonView(for: item)
        }
    }

    // MARK: - Button

    private func buttonView(for item: ActionItem) -> some View {
        let isHovered = hoveredID == item.id

        return Button {
            onAction(item, nil)
        } label: {
            VStack(spacing: 2) {
                if let icon = item.icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }
                Text(item.label)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(minWidth: 48, minHeight: 40)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? .white.opacity(0.15) : .clear)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .onHover { hovering in
            hoveredID = hovering ? item.id : nil
        }
    }

    // MARK: - Slider

    private func sliderView(for item: ActionItem) -> some View {
        let minVal = item.config?.min ?? 0
        let maxVal = item.config?.max ?? 100
        let currentValue = Binding<Double>(
            get: { sliderValues[item.id] ?? minVal },
            set: { newVal in
                sliderValues[item.id] = newVal
                throttledAction(item: item, value: newVal)
            }
        )

        return HStack(spacing: 6) {
            if let icon = item.icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Slider(value: currentValue, in: minVal...maxVal)
                .frame(width: 120)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Toggle

    private func toggleView(for item: ActionItem) -> some View {
        let isOn = toggleStates[item.id] ?? false
        let isHovered = hoveredID == item.id

        return Button {
            let newState = !isOn
            toggleStates[item.id] = newState
            onAction(item, newState ? 1 : 0)
        } label: {
            VStack(spacing: 2) {
                if let icon = item.icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }
                Text(item.label)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(minWidth: 48, minHeight: 40)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isOn ? Color.accentColor.opacity(0.3) : (isHovered ? .white.opacity(0.15) : .clear))
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn ? Color.accentColor : .primary)
        .onHover { hovering in
            hoveredID = hovering ? item.id : nil
        }
    }

    // MARK: - Throttle

    private func throttledAction(item: ActionItem, value: Double) {
        onAction(item, value)
    }

    // MARK: - State update from external source

    func withUpdatedStates(sliders: [String: Double], toggles: [String: Bool]) -> TouchBarContentView {
        var copy = self
        copy._sliderValues = State(initialValue: sliders)
        copy._toggleStates = State(initialValue: toggles)
        return copy
    }
}
