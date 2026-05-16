import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case camera, library, automation, settings
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .library: return "photo.on.rectangle"
        case .automation: return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }
    var title: String {
        switch self {
        case .camera: return Strings.cameraTitle
        case .library: return Strings.libraryTitle
        case .automation: return Strings.automationTitle
        case .settings: return Strings.settingsTitle
        }
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    init(material: NSVisualEffectView.Material = .sidebar, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct ContentView: View {
    @EnvironmentObject var lang: LanguageManager
    @State private var selectedItem: SidebarItem = .camera
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            VStack(spacing: 0) {
                // App title
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Mac监控系统")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider()
                    .padding(.horizontal, 12)

                // Navigation items
                VStack(spacing: 2) {
                    ForEach(SidebarItem.allCases) { item in
                        sidebarRow(item)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Spacer()
            }
            .frame(minWidth: 180, idealWidth: 200)
            .background(VisualEffectBlur(material: .sidebar))
        } detail: {
            // Detail
            Group {
                switch selectedItem {
                case .camera:
                    CameraView()
                case .library:
                    MediaLibraryView()
                case .automation:
                    AutomationView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: selectedItem)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            columnVisibility = columnVisibility == .all ? .detailOnly : .all
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .help("Toggle Sidebar")
                }
            }
        }
        .frame(minWidth: 900, minHeight: 540)
    }

    private func sidebarRow(_ item: SidebarItem) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedItem = item
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(selectedItem == item ? .white : .secondary)
                    .frame(width: 24)
                Text(item.title)
                    .font(.system(size: 13, weight: selectedItem == item ? .semibold : .regular))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedItem == item ? Color.accentColor : Color.clear)
            )
            .foregroundStyle(selectedItem == item ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
