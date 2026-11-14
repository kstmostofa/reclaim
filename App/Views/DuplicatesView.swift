import ReclaimCore
import SwiftUI

/// Groups of identical files. Nothing is ticked for you; the Keep menu ticks every copy but one.
struct DuplicatesView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @State private var search = ""
    @State private var pickingFolder = false

    private var groups: [DuplicateGroup] {
        let all = model.duplicates ?? []
        guard !search.isEmpty else { return all }
        return all.filter { $0.files.contains { $0.path.localizedCaseInsensitiveContains(search) } }
    }

    var body: some View {
        content
            .navigationTitle("Duplicates")
            .navigationSubtitle(subtitle)
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button("Keep Oldest Copy") { model.keep(.oldest, in: groups) }
                        Button("Keep Newest Copy") { model.keep(.newest, in: groups) }
                        Button("Keep the Copy in a Folder…") { pickingFolder = true }
                        Divider()
                        Button("Untick All Copies") { model.ticked.subtract(groups.flatMap { $0.files.map(\.path) }) }
                    } label: {
                        Label("Keep", systemImage: "checklist")
                    }
                    .help("Tick every copy except one, in each group shown")
                    .disabled(groups.isEmpty)
                }
            }
            .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result { model.keep(.inFolder(url.path), in: groups) }
            }
    }

    private var subtitle: String {
        guard let all = model.duplicates else { return "" }
        let reclaimable = all.reduce(0) { $0 + $1.reclaimable }
        return "\(all.count) groups · \(Format.size(reclaimable)) reclaimable"
    }

    @ViewBuilder private var content: some View {
        if model.tree == nil {
            ContentUnavailableView(model.phase == .scanning ? "Scanning…" : "No Scan Yet", systemImage: "doc.on.doc",
                                   description: Text("Scan the disk first, then look for duplicate files."))
        } else if model.isFindingDuplicates {
            VStack(spacing: 12) {
                ProgressView()
                Text(model.duplicateProgress.stage.isEmpty ? "Starting…" : model.duplicateProgress.stage)
                    .font(.headline)
                Text("\(Format.count(model.duplicateProgress.filesRead)) files read · \(Format.size(model.duplicateProgress.bytesRead))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button("Stop") { model.cancelDuplicates() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.duplicates == nil {
            ContentUnavailableView {
                Label("Find Duplicate Files", systemImage: "doc.on.doc")
            } description: {
                Text("Compares files of \(settings.duplicateMinimumMB) MB or more in the last scan, outside apps, libraries and tool folders. Only files with identical contents are listed.")
            } actions: {
                Button("Find Duplicates") { model.findDuplicates() }
                    .buttonStyle(.borderedProminent)
            }
        } else if groups.isEmpty {
            ContentUnavailableView(search.isEmpty ? "No Duplicates" : "No Matches", systemImage: "checkmark.circle",
                                   description: Text(search.isEmpty ? "No identical files were found." : "No copies match “\(search)”."))
        } else {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.files) { file in
                            DuplicateRow(group: group, file: file)
                        }
                    } header: {
                        GroupHeader(group: group)
                    }
                }
            }
            .searchable(text: $search, placement: .toolbar, prompt: "Filter by name or folder")
            .safeAreaInset(edge: .top) {
                HStack {
                    Text("Nothing here is ticked for you. Use Keep to tick all but one copy, or tick copies yourself.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Search Again") { model.findDuplicates() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
    }
}

private struct GroupHeader: View {
    @Environment(AppModel.self) private var model
    let group: DuplicateGroup

    var body: some View {
        let allTicked = group.files.allSatisfy { model.ticked.contains($0.path) }
        HStack(spacing: 8) {
            Text(group.files[0].name).font(.headline).lineLimit(1)
            Text("\(group.files.count) copies of \(Format.size(group.size))")
                .foregroundStyle(.secondary)
            if allTicked {
                Label("Every copy is ticked", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            Spacer()
            Text("\(Format.size(group.reclaimable)) reclaimable")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct DuplicateRow: View {
    @Environment(AppModel.self) private var model
    let group: DuplicateGroup
    let file: DuplicateFile

    var body: some View {
        HStack(spacing: 8) {
            Toggle("Delete \(file.name)", isOn: Binding(
                get: { model.ticked.contains(file.path) },
                set: { on in
                    if on { model.ticked.insert(file.path) } else { model.ticked.remove(file.path) }
                }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            Image(nsImage: FileIcons.icon(for: file.path))
                .resizable()
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name).lineLimit(1)
                Text(abbreviated(file.folder))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(file.path)
            }
            Spacer()
            if group.sharesStorage(file) {
                Text("Shares storage")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                    .help("An APFS copy that shares its storage with another copy here. Deleting it frees almost nothing.")
            }
            Text(file.modified, format: .dateTime.year().month().day())
                .foregroundStyle(.secondary)
                .frame(minWidth: 90, alignment: .trailing)
        }
        .contextMenu {
            Button("Keep Only This Copy") {
                model.ticked.formUnion(group.files.filter { $0.path != file.path }.map(\.path))
                model.ticked.remove(file.path)
            }
            Button("Reveal in Finder") { model.reveal(file.path) }
        }
    }
}
