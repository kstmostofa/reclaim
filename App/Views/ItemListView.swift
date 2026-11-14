import ReclaimCore
import SwiftUI

/// A tickable table of suggestions: one category, or Large Files.
struct ItemListView: View {
    @Environment(AppModel.self) private var model
    let title: String
    let items: [Suggestion]
    var emptyMessage = "Nothing here."

    @State private var sortOrder = [KeyPathComparator(\Suggestion.size, order: .reverse)]
    @State private var search = ""
    @State private var selection = Set<Suggestion.ID>()
    @State private var showInspector = true

    private var rows: [Suggestion] {
        let all = items
        let filtered = search.isEmpty ? all : all.filter {
            $0.path.localizedCaseInsensitiveContains(search) || $0.match.title.localizedCaseInsensitiveContains(search)
        }
        return filtered.sorted(using: sortOrder)
    }

    var body: some View {
        let rows = rows
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("") { item in
                Toggle("Delete \(item.name)", isOn: tickBinding(item.path))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
            }
            .width(22)

            TableColumn("Name", value: \.name) { item in
                HStack(spacing: 8) {
                    Image(nsImage: FileIcons.icon(for: item.path))
                        .resizable()
                        .frame(width: 20, height: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(item.name).lineLimit(1)
                            if model.belongsToRunningApp(item) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .help("This app is running. Quit it before deleting its files.")
                            }
                        }
                        Text(abbreviated((item.path as NSString).deletingLastPathComponent))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(item.path)
                    }
                }
            }
            .width(min: 180, ideal: 250)

            TableColumn("Size", value: \.size) { item in
                Text(Format.size(item.size)).monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 64, ideal: 72)

            TableColumn("Safety", value: \.level) { item in
                SafetyBadge(level: item.level)
            }
            .width(min: 70, ideal: 80)

            TableColumn("Modified", value: \.modified) { item in
                Text(item.modified, format: .dateTime.year().month().day())
                    .foregroundStyle(.secondary)
            }
            .width(min: 76, ideal: 90)
        }
        .contextMenu(forSelectionType: Suggestion.ID.self) { ids in
            Button("Tick") { model.ticked.formUnion(ids) }
            Button("Untick") { model.ticked.subtract(ids) }
            if ids.count == 1, let id = ids.first {
                Divider()
                Button("Reveal in Finder") { model.reveal(id) }
            }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Filter by name or path")
        .navigationTitle(title)
        .navigationSubtitle("\(rows.count) items · \(Format.size(model.total(of: rows)))")
        .toolbar {
            ToolbarItemGroup {
                Button("Select All Safe") { model.tickAllSafe(in: rows) }
                    .disabled(!rows.contains { $0.level == .safe })
                Button("Deselect All") { model.untick(rows) }
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
            }
        }
        .inspector(isPresented: $showInspector) {
            InspectorView(item: rows.first { selection.contains($0.id) })
                .inspectorColumnWidth(min: 240, ideal: 280, max: 400)
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView(model.phase == .scanning ? "Scanning…" : "Nothing to Show",
                                       systemImage: "checkmark.circle", description: Text(emptyMessage))
            }
        }
    }

    private func tickBinding(_ path: String) -> Binding<Bool> {
        Binding(
            get: { model.ticked.contains(path) },
            set: { on in
                if on { model.ticked.insert(path) } else { model.ticked.remove(path) }
            }
        )
    }
}

struct SafetyBadge: View {
    let level: SafetyLevel

    var body: some View {
        Text(level.title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var color: Color {
        switch level {
        case .safe: .green
        case .rebuild: .orange
        case .personal: .purple
        }
    }
}

struct InspectorView: View {
    @Environment(AppModel.self) private var model
    let item: Suggestion?

    var body: some View {
        if let item {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(nsImage: FileIcons.icon(for: item.path))
                            .resizable()
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).font(.headline).lineLimit(2)
                            Text(item.match.title).foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        SafetyBadge(level: item.level)
                        Spacer()
                        Text(Format.size(item.size)).font(.title3.weight(.semibold)).monospacedDigit()
                    }
                    if model.belongsToRunningApp(item) {
                        Label("This app is running. Quit it before deleting its files.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                    section("Why it is suggested", item.match.reason)
                    section("After deleting", item.match.consequence)
                    section("Location", item.path)
                        .textSelection(.enabled)
                    section("Last modified", item.modified.formatted(date: .abbreviated, time: .shortened))
                    Button("Reveal in Finder") { model.reveal(item.path) }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("No Selection", systemImage: "sidebar.right",
                                   description: Text("Select an item to see what it is."))
        }
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

func abbreviated(_ path: String) -> String {
    let home = NSHomeDirectory()
    return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
}

@MainActor
enum FileIcons {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for path: String) -> NSImage {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(icon, forKey: path as NSString)
        return icon
    }
}
