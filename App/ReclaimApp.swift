import ReclaimCore
import SwiftUI

@main
struct ReclaimApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Reclaim", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 900, minHeight: 560)
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
        }
    }
}

enum SidebarItem: Hashable {
    case overview
    case category(SuggestionCategory)
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: SidebarItem? = .overview

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            VStack(spacing: 0) {
                switch selection {
                case .category(let category):
                    SuggestionsView(category: category)
                case .overview, nil:
                    OverviewView(selection: $selection)
                }
                if !model.ticked.isEmpty {
                    ActionBar()
                }
            }
        }
        .task {
            // `-autoScan YES` on the command line starts a scan at launch; used for screenshots.
            if UserDefaults.standard.bool(forKey: "autoScan") && model.phase == .idle { model.startScan() }
        }
        .sheet(isPresented: .constant(model.deletion != nil)) {
            DeletionSheet()
                .environment(model)
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
        }
    }
}
