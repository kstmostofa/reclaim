import ReclaimCore
import SwiftUI

@main
struct ReclaimApp: App {
    @State private var settings: AppSettings
    @State private var model: AppModel

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _model = State(initialValue: AppModel(settings: settings))
    }

    var body: some Scene {
        Window("Reclaim", id: "main") {
            ContentView()
                .environment(model)
                .environment(settings)
                .tint(settings.accentColor)
                .frame(minWidth: 900, minHeight: 560)
                .onAppear { settings.applyAppearance() }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Scan") { model.startScan() }
                    .keyboardShortcut("r")
                    .disabled(model.phase == .scanning)
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .environment(settings)
                .tint(settings.accentColor)
        }
    }
}

enum SidebarItem: Hashable {
    case overview
    case category(SuggestionCategory)
    case diskMap
    case largeFiles
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @State private var selection: SidebarItem? = .overview
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            VStack(spacing: 0) {
                switch selection {
                case .category(let category):
                    ItemListView(title: category.title, items: model.suggestions(in: category))
                        .id(category)
                case .largeFiles:
                    ItemListView(title: "Large Files", items: model.largeFiles,
                                 emptyMessage: "No files of \(settings.largeFileThresholdMB) MB or more outside the suggestions.")
                case .diskMap:
                    DiskMapView()
                case .overview, nil:
                    OverviewView(selection: $selection)
                }
                if !model.ticked.isEmpty {
                    ActionBar()
                }
            }
        }
        .sheet(isPresented: .constant(model.deletion != nil)) {
            DeletionSheet()
                .environment(model)
                .environment(settings)
                .tint(settings.accentColor)
        }
        .task {
            // `-autoScan YES` on the command line starts a scan at launch; used for screenshots.
            if UserDefaults.standard.bool(forKey: "autoScan") && model.phase == .idle { model.startScan() }
            // `-openSettings YES` opens Settings at launch, for the same reason.
            if UserDefaults.standard.bool(forKey: "openSettings") { openSettings() }
        }
        .onChange(of: settings.largeFileThresholdMB) { model.recomputeLargeFiles() }
    }
}

struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Label("Overview", systemImage: "internaldrive")
                .tag(SidebarItem.overview)
            Section("Suggestions") {
                if model.categories.isEmpty {
                    Text(model.phase == .scanning ? "Scanning…" : "Scan to see suggestions")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.categories, id: \.category) { entry in
                    Label(entry.category.title, systemImage: entry.category.systemImage)
                        .badge(Text(Format.size(entry.size)).monospacedDigit())
                        .tag(SidebarItem.category(entry.category))
                }
            }
            Section("Explore") {
                Label("Disk Map", systemImage: "chart.bar.doc.horizontal")
                    .tag(SidebarItem.diskMap)
                Label("Large Files", systemImage: SuggestionCategory.largeFiles.systemImage)
                    .badge(model.largeFiles.isEmpty ? nil : Text(Format.size(model.total(of: model.largeFiles))).monospacedDigit())
                    .tag(SidebarItem.largeFiles)
            }
        }
    }
}
