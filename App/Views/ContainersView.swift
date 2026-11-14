import ReclaimCore
import SwiftUI

/// What Docker (through Docker Desktop, OrbStack or another engine) can remove, removed with Docker's own commands.
struct ContainersView: View {
    @Environment(AppModel.self) private var model
    @State private var sortOrder = [KeyPathComparator(\DockerItem.size, order: .reverse)]
    @State private var selection = Set<DockerItem.ID>()

    var body: some View {
        content
            .navigationTitle("Containers")
            .navigationSubtitle(subtitle)
            .toolbar {
                ToolbarItemGroup {
                    Button("Select All Safe") {
                        model.ticked.formUnion(model.dockerItems.filter { $0.level == .safe }.map(\.path))
                    }
                    .disabled(!model.dockerItems.contains { $0.level == .safe })
                    Button {
                        model.refreshDocker()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isLoadingDocker)
                }
            }
            .task {
                if model.dockerStatus == nil { model.refreshDocker() }
            }
    }

    private var subtitle: String {
        guard case .running(let engine) = model.dockerStatus else { return "" }
        return "\(engine) · \(model.dockerItems.count) items · \(Format.size(model.dockerItems.reduce(0) { $0 + $1.size }))"
    }

    @ViewBuilder private var content: some View {
        switch model.dockerStatus {
        case nil:
            ProgressView("Checking Docker…").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .notInstalled:
            ContentUnavailableView("Docker Isn't Installed", systemImage: "shippingbox",
                                   description: Text("Reclaim cleans up Docker Desktop, OrbStack and other Docker engines when the docker command is installed."))
        case .notRunning(let reason):
            ContentUnavailableView {
                Label("Docker Isn't Running", systemImage: "shippingbox")
            } description: {
                VStack(spacing: 8) {
                    Text("Start OrbStack or Docker Desktop, then refresh.")
                    Text(reason).font(.caption).foregroundStyle(.tertiary).textSelection(.enabled)
                }
            } actions: {
                Button("Refresh") { model.refreshDocker() }
            }
        case .running:
            if let error = model.dockerError {
                ContentUnavailableView("Couldn't Read Docker's Disk Usage", systemImage: "exclamationmark.triangle",
                                       description: Text(error))
            } else if model.dockerItems.isEmpty {
                ContentUnavailableView(model.isLoadingDocker ? "Loading…" : "Nothing to Remove",
                                       systemImage: "checkmark.circle",
                                       description: Text("No build cache, unused images, stopped containers or unused volumes."))
            } else {
                table
            }
        }
    }

    private var table: some View {
        let rows = model.dockerItems.sorted(using: sortOrder)
        return Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("") { item in
                Toggle("Remove \(item.name)", isOn: Binding(
                    get: { model.ticked.contains(item.path) },
                    set: { on in
                        if on { model.ticked.insert(item.path) } else { model.ticked.remove(item.path) }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.checkbox)
            }
            .width(22)

            TableColumn("Name", value: \.name) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.kind.systemImage)
                        .foregroundStyle(.tint)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name).lineLimit(1)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .help(item.kind.reason)
            }
            .width(min: 200, ideal: 300)

            TableColumn("Kind", value: \.kind.title) { item in
                Text(item.kind.title).foregroundStyle(.secondary)
            }
            .width(min: 110, ideal: 130)

            TableColumn("Size", value: \.size) { item in
                Text(Format.size(item.size)).monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 64, ideal: 76)

            TableColumn("Safety", value: \.level) { item in
                SafetyBadge(level: item.level)
            }
            .width(min: 70, ideal: 80)
        }
        .safeAreaInset(edge: .bottom) {
            if let item = rows.first(where: { selection.contains($0.id) }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.kind.reason)
                    Text("After removing: \(item.kind.consequence)").foregroundStyle(.secondary)
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.bar)
            } else {
                Text("Removed with Docker's own commands. Docker refuses anything a container is using.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.bar)
            }
        }
    }
}
