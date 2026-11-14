import ReclaimCore
import SwiftUI

@main
struct ReclaimApp: App {
    @State private var settings: AppSettings
    @State private var model: AppModel

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        let model = AppModel(settings: settings)
        _model = State(initialValue: model)
        model.startBackgroundWork()
    }

    var body: some Scene {
        Window("Reclaim", id: "main") {
            ContentView()
                .environment(model)
                .environment(settings)
                .tint(settings.accentColor)
                .frame(minWidth: 980, minHeight: 560)
                .onAppear { settings.applyAppearance() }
        }
        .defaultSize(width: 1200, height: 760)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Scan") { model.startScan() }
                    .keyboardShortcut("r")
                    .disabled(model.phase == .scanning)
            }
        }

        MenuBarExtra(isInserted: Binding(get: { settings.showMenuBar }, set: { settings.showMenuBar = $0 })) {
            MenuBarView()
                .environment(model)
                .environment(settings)
                .tint(settings.accentColor)
        } label: {
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)

        // The menu-bar window's content in an ordinary window, opened by `-previewMenuBar YES` for screenshots.
        Window("Menu Bar Preview", id: "menubar-preview") {
            MenuBarView()
                .environment(model)
                .environment(settings)
                .tint(settings.accentColor)
        }
        .windowResizability(.contentSize)

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
    case duplicates
    case containers
    case system
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    /// `-section duplicates` (or diskMap, largeFiles) opens that screen at launch; used for screenshots.
    @State private var selection: SidebarItem? = ContentView.launchSection()
    @AppStorage("showInspector") private var showInspector = true

    /// The inspector belongs to the suggestion lists. It is a column of the window rather than of the detail
    /// view, because an inspector inside a split view's detail pushes the whole window sideways as it opens.
    private var inspectorShown: Binding<Bool> {
        Binding(
            get: {
                switch selection {
                case .category, .largeFiles: showInspector
                default: false
                }
            },
            set: { showInspector = $0 }
        )
    }
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    private static func launchSection() -> SidebarItem {
        switch UserDefaults.standard.string(forKey: "section") {
        case "diskMap": .diskMap
        case "largeFiles": .largeFiles
        case "duplicates": .duplicates
        case "containers": .containers
        case "system": .system
        default: .overview
        }
    }

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
                case .duplicates:
                    DuplicatesView()
                case .containers:
                    ContainersView()
                case .system:
                    SystemView(selection: $selection)
                case .overview, nil:
                    OverviewView(selection: $selection)
                }
                if !model.ticked.isEmpty {
                    ActionBar()
                }
            }
        }
        .inspector(isPresented: inspectorShown) {
            InspectorView(item: model.inspected)
                .inspectorColumnWidth(min: 240, ideal: 280, max: 400)
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
            // `-helperSelfTest <path>` asks the installed helper to delete that path and /etc/hosts, and logs the
            // answers; used to check a real install without clicking through the app.
            if let target = UserDefaults.standard.string(forKey: "helperSelfTest") {
                let status = await model.helper.status()
                FileHandle.standardError.write(Data("helper status: \(status)\n".utf8))
                let results = (try? await model.helper.remove(paths: [target, "/etc/hosts"])) ?? [:]
                FileHandle.standardError.write(Data("helper results: \(results)\n".utf8))
            }
            if UserDefaults.standard.bool(forKey: "previewMenuBar") { openWindow(id: "menubar-preview") }
            // `-openSettings YES` opens Settings at launch, for the same reason.
            if UserDefaults.standard.bool(forKey: "openSettings") { openSettings() }
        }
        .onChange(of: settings.largeFileThresholdMB) { model.recomputeLargeFiles() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshAccess()
            model.refreshRunningApps()
        }
        .onChange(of: model.phase) {
            // `-autoDuplicates YES` searches for duplicates as soon as a scan finishes, for screenshots.
            if model.phase == .scanned && UserDefaults.standard.bool(forKey: "autoDuplicates") { model.findDuplicates() }
        }
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
                Label("Duplicates", systemImage: SuggestionCategory.duplicates.systemImage)
                    .badge(model.duplicates.map { Text(Format.size($0.reduce(0) { $0 + $1.reclaimable })).monospacedDigit() })
                    .tag(SidebarItem.duplicates)
                Label("Containers", systemImage: SuggestionCategory.containers.systemImage)
                    .badge(model.dockerItems.isEmpty ? nil : Text(Format.size(model.dockerItems.reduce(0) { $0 + $1.size })).monospacedDigit())
                    .tag(SidebarItem.containers)
                Label("System", systemImage: "lock.shield")
                    .badge(model.helperStatus == .needsPairing ? Text("!") : nil)
                    .tag(SidebarItem.system)
            }
        }
    }
}
