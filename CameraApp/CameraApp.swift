import SwiftUI

/// Shared controller for menu bar quick capture
final class CaptureController: ObservableObject {
    static let shared = CaptureController()
    weak var cameraManager: CameraManager?

    func quickCapture() {
        if let camera = cameraManager {
            camera.ensureSessionRunning {
                camera.capturePhoto()
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var instance: AppDelegate?
    var mainWindow: NSWindow?
    private var windowReady = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self

        // Capture the SwiftUI window once it's created, then hide dock icon
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.captureMainWindow()
            self?.mainWindow?.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.setActivationPolicy(.accessory)
                self?.windowReady = true
            }
        }
    }

    private func captureMainWindow() {
        for window in NSApp.windows {
            if window.contentView != nil && window.level == .normal
                && !window.isKind(of: NSClassFromString("NSStatusBarWindow") ?? NSWindow.self) {
                mainWindow = window
                window.delegate = self
                window.isReleasedWhenClosed = false
                break
            }
        }
    }

    func showMainWindow() {
        guard windowReady else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showMainWindow()
            }
            return
        }

        NSApp.setActivationPolicy(.regular)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }

            if self.mainWindow == nil || self.mainWindow?.contentView == nil {
                self.captureMainWindow()
            }

            if let window = self.mainWindow {
                window.orderFrontRegardless()
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
        return true
    }
}

@main
struct CameraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var settingsStore = SettingsStore.shared
    @StateObject private var mediaLibrary = MediaLibraryManager.shared
    @StateObject private var telegramService = TelegramService.shared
    @StateObject private var automationScheduler = AutomationScheduler.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageManager)
                .environmentObject(settingsStore)
                .environmentObject(mediaLibrary)
                .environmentObject(telegramService)
                .environmentObject(automationScheduler)
                .onAppear {
                    mediaLibrary.scanLibrary()
                    automationScheduler.restoreAllTasks()
                    setupAutomationCapture()
                }
                .id(languageManager.currentLanguage)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 600)

        MenuBarExtra {
            MenuBarMenu()
                .environmentObject(languageManager)
                .environmentObject(settingsStore)
                .environmentObject(mediaLibrary)
                .environmentObject(telegramService)
                .environmentObject(automationScheduler)
        } label: {
            Image(systemName: automationScheduler.isAutomationEnabled ? "camera.metering.spot" : "camera")
        }
        .menuBarExtraStyle(.window)
    }

    private func setupAutomationCapture() {
        let camera = CameraManager.shared
        automationScheduler.onCapture = { [weak camera] telegramSend in
            guard let camera else { return }
            camera.ensureSessionRunning {
                camera.capturePhoto()
                if telegramSend, let path = camera.lastSavedPhotoPath,
                   let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                    TelegramService.shared.sendPhoto(imageData: data)
                }
            }
        }
    }
}

struct MenuBarMenu: View {
    @EnvironmentObject var automation: AutomationScheduler
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Image(systemName: "camera.fill")
                    .font(.title2)
                Text("Mac监控系统")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(automation.isAutomationEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider()

            // Automation toggle
            HStack {
                Image(systemName: automation.isAutomationEnabled ? "play.circle.fill" : "pause.circle.fill")
                    .foregroundStyle(automation.isAutomationEnabled ? .green : .secondary)
                Text(Strings.toggleAutomation)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { automation.isAutomationEnabled },
                    set: { automation.setAutomationEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
            }
            .padding(.horizontal, 12)

            // Quick capture
            Button {
                CaptureController.shared.quickCapture()
            } label: {
                HStack {
                    Image(systemName: "camera.circle")
                    Text(Strings.quickPhoto)
                    Spacer()
                    Text("⇧⌘P")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 8)

            Divider()

            // Open control panel
            Button {
                AppDelegate.instance?.showMainWindow()
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("打开控制面板")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // Quit
            Button {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                        .foregroundStyle(.red)
                    Text(Strings.quit)
                        .foregroundStyle(.red)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .padding(.bottom, 8)
        }
        .frame(width: 240)
    }
}
