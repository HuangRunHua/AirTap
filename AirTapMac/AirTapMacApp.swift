import SwiftUI
import ApplicationServices

@main
struct AirTapMacApp: App {
    @StateObject private var server = CommandServer()
    @StateObject private var touchBarController = TouchBarController()

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(server: server, touchBarController: touchBarController)
        } label: {
            Image(systemName: server.connectedDevice != nil
                  ? "antenna.radiowaves.left.and.right"
                  : "antenna.radiowaves.left.and.right.slash")
        }
        .menuBarExtraStyle(.window)
    }
}

struct StatusMenuView: View {
    @ObservedObject var server: CommandServer
    @ObservedObject var touchBarController: TouchBarController
    private var accessGranted: Bool { AXIsProcessTrusted() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                server.isRunning ? "服务运行中" : "服务未启动",
                systemImage: server.isRunning ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundStyle(server.isRunning ? .green : .red)

            if let device = server.connectedDevice {
                Label("已连接: \(device)", systemImage: "iphone")
                    .foregroundStyle(.green)
            } else {
                Label("等待 iPhone 连接…", systemImage: "iphone.slash")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle(isOn: $touchBarController.isEnabled) {
                Label("Touch Bar", systemImage: "rectangle.bottomhalf.filled")
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Divider()

            if accessGranted {
                Label("辅助功能已授权", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            } else {
                Label("需要辅助功能权限", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Button("前往授权…") {
                    AccessibilityMonitor.requestPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Divider()

            Button("退出 AirTap") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 240)
        .onAppear {
            server.start()
            touchBarController.start()
        }
    }
}
