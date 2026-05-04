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
}

struct ContentView: View {
    @EnvironmentObject var lang: LanguageManager
    @State private var selectedItem: SidebarItem = .camera

    var body: some View {
        TabView(selection: $selectedItem) {
            CameraView()
                .tabItem { Label(Strings.cameraTitle, systemImage: "camera.fill") }
                .tag(SidebarItem.camera)

            MediaLibraryView()
                .tabItem { Label(Strings.libraryTitle, systemImage: "photo.on.rectangle") }
                .tag(SidebarItem.library)

            AutomationView()
                .tabItem { Label(Strings.automationTitle, systemImage: "clock.arrow.circlepath") }
                .tag(SidebarItem.automation)

            SettingsView()
                .tabItem { Label(Strings.settingsTitle, systemImage: "gearshape.fill") }
                .tag(SidebarItem.settings)
        }
        .frame(minWidth: 900, minHeight: 540)
    }
}
