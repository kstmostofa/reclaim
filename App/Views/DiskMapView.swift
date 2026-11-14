import ReclaimCore
import SwiftUI

/// The whole scanned tree, largest first, one folder at a time. Anything not protected can be ticked.
struct DiskMapView: View {
    @Environment(AppModel.self) private var model
    @State private var currentPath: String?
    @State private var selection = Set<FileNode.ID>()
    @State private var sortOrder = [KeyPathComparator(\FileNode.size, order: .reverse)]

    var body: some View {
        if let tree = model.tree {
            let current = currentPath.flatMap { tree.node(at: $0) } ?? tree
            VStack(spacing: 0) {
                Breadcrumbs(tree: tree, current: current) { currentPath = $0 }
                Divider()
                table(current)
                if current.otherFilesSize > 0 {
                    Text("Plus \(Format.size(current.otherFilesSize)) in files under 1 MB, not listed one by one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
            }
            .navigationTitle("Disk Map")
            .navigationSubtitle("\(displayName(current, in: tree)) · \(Format.size(current.size))")
            .toolbar {
                ToolbarItem {
                    Button {
                        currentPath = (current.path as NSString).deletingLastPathComponent
                    } label: {
                        Label("Enclosing Folder", systemImage: "chevron.up")
                    }
                    .disabled(current === tree)
                    .keyboardShortcut(.upArrow, modifiers: .command)
                }
            }
            .onChange(of: currentPath) { selection = [] }
        } else {
            ContentUnavailableView(model.phase == .scanning ? "Scanning…" : "No Scan Yet",
                                   systemImage: "chart.bar.doc.horizontal",
                                   description: Text("Scan the disk to see what takes up space, folder by folder."))
                .navigationTitle("Disk Map")
        }
    }

    private func table(_ current: FileNode) -> some View {
        let rows = current.children.sorted(using: sortOrder)
        let parentSize = max(current.size, 1)
        return Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("") { node in
                Toggle("Delete \(node.name)", isOn: tickBinding(node))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .disabled(!model.canDelete(node.path))
                    .help(model.canDelete(node.path) ? "" : "Protected: never deleted as a whole.")
            }
            .width(22)

            TableColumn("Name", value: \.name) { node in
                HStack(spacing: 8) {
                    Image(nsImage: FileIcons.icon(for: node.path))
                        .resizable()
                        .frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(node.name).lineLimit(1)
                            if node.isUnreadable {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.secondary)
                                    .help("Could not be read; its size is a lower bound.")
                            }
                        }
                        SizeBar(fraction: Double(node.size) / Double(parentSize))
                    }
                    if let match = node.match {
                        SafetyBadge(level: match.level).help(match.title)
                    }
                }
            }
            .width(min: 220, ideal: 340)

            TableColumn("Size", value: \.size) { node in
                Text(Format.size(node.size)).monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 80)

            TableColumn("Share") { node in
                Text(Double(node.size) / Double(parentSize), format: .percent.precision(.fractionLength(1)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 50, ideal: 56)

            TableColumn("Files", value: \.fileCount) { node in
                Text(Format.count(node.fileCount)).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 60, ideal: 72)

            TableColumn("Modified", value: \.modified) { node in
                Text(node.modified, format: .dateTime.year().month().day())
                    .foregroundStyle(.secondary)
            }
            .width(min: 76, ideal: 90)
        }
        .contextMenu(forSelectionType: FileNode.ID.self) { ids in
            if ids.count == 1, let id = ids.first, let node = current.children.first(where: { $0.id == id }) {
                if node.isDirectory {
                    Button("Open") { currentPath = node.path }
                }
                Button("Reveal in Finder") { model.reveal(node.path) }
                Divider()
            }
            Button("Tick") {
                for node in current.children where ids.contains(node.id) { model.setTicked(node, true) }
            }
            Button("Untick") { model.ticked.subtract(ids) }
        } primaryAction: { ids in
            if ids.count == 1, let id = ids.first, let node = current.children.first(where: { $0.id == id }), node.isDirectory {
                currentPath = node.path
            }
        }
    }

    private func tickBinding(_ node: FileNode) -> Binding<Bool> {
        Binding(get: { model.ticked.contains(node.path) }, set: { model.setTicked(node, $0) })
    }
}

/// The trail from the scanned root to the folder on screen; each step opens that folder.
private struct Breadcrumbs: View {
    let tree: FileNode
    let current: FileNode
    let open: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(trail.enumerated()), id: \.element.path) { index, node in
                    if index > 0 {
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    }
                    Button(displayName(node, in: tree)) { open(node.path) }
                        .buttonStyle(.plain)
                        .foregroundStyle(node === current ? .primary : .secondary)
                        .fontWeight(node === current ? .semibold : .regular)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var trail: [FileNode] {
        var out = [tree]
        while let last = out.last, last !== current,
              let next = last.children.first(where: { current.path == $0.path || current.path.hasPrefix($0.path + "/") }) {
            out.append(next)
        }
        return out
    }
}

private struct SizeBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(.tint).frame(width: max(2, geo.size.width * min(fraction, 1)))
            }
        }
        .frame(height: 4)
        .frame(maxWidth: 220)
    }
}

/// The volume's name for the scanned data volume, otherwise the folder's own name.
@MainActor
private func displayName(_ node: FileNode, in tree: FileNode) -> String {
    if node === tree && node.path == DiskScanner.dataVolumePath {
        return VolumeInfo.forPath()?.name ?? "Macintosh HD"
    }
    return node === tree ? abbreviated(node.path) : node.name
}
