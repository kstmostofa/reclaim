import ReclaimCore
import SwiftUI

/// The root helper's status, local Time Machine snapshots, and a pointer to system caches and logs.
struct SystemView: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: SidebarItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                helperCard
                systemJunk
                snapshotsSection
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("System")
        .task { model.refreshHelper() }
    }

    // MARK: Helper

    private var helperCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Helper", systemImage: "lock.shield").font(.headline)
                    Spacer()
                    statusBadge
                }
                Text("Some caches, logs and leftovers belong to root, the system's administrator account, so Reclaim can't delete them by itself. The optional helper can. It runs in the background as root, deletes only inside system cache and log folders and your home folder, and only takes orders from this copy of Reclaim.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                switch model.helperStatus {
                case .notInstalled:
                    Text("Installing asks for your Mac password once, in macOS's own dialog.")
                        .font(.callout).foregroundStyle(.secondary)
                case .needsPairing:
                    Text("Reclaim was updated or rebuilt since the helper was installed, so the helper no longer accepts it. Pair them again; macOS asks for your password once.")
                        .font(.callout).foregroundStyle(.orange)
                case .ready, nil:
                    EmptyView()
                }
                if let error = model.helperError {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
                HStack {
                    switch model.helperStatus {
                    case .notInstalled:
                        Button("Install Helper…") { model.installHelper() }.buttonStyle(.borderedProminent)
                    case .needsPairing:
                        Button("Pair Again…") { model.installHelper() }.buttonStyle(.borderedProminent)
                        Button("Remove Helper…") { model.uninstallHelper() }
                    case .ready:
                        Button("Remove Helper…") { model.uninstallHelper() }
                    case nil:
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder private var statusBadge: some View {
        switch model.helperStatus {
        case .ready: Label("Installed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .needsPairing: Label("Needs pairing", systemImage: "exclamationmark.circle.fill").foregroundStyle(.orange)
        case .notInstalled: Label("Not installed", systemImage: "circle.dashed").foregroundStyle(.secondary)
        case nil: EmptyView()
        }
    }

    // MARK: System junk

    private var systemJunk: some View {
        let items = model.suggestions(in: .system)
        return VStack(alignment: .leading, spacing: 8) {
            Text("System caches and logs").font(.headline)
            Button {
                selection = .category(.system)
            } label: {
                HStack {
                    Image(systemName: SuggestionCategory.system.systemImage).foregroundStyle(.tint).frame(width: 22)
                    Text(items.isEmpty ? "None found in the last scan" : "\(items.count) items in /Library/Caches, /Library/Logs and /private/var/log")
                    Spacer()
                    Text(Format.size(model.total(of: items))).monospacedDigit()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .padding(.vertical, 9)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(items.isEmpty)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
            if model.helperStatus != .ready && items.contains(where: { !$0.isDeletableByUser }) {
                Text("Items owned by root show their size as far as Reclaim could read it. With the helper installed, they are measured in full.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Snapshots

    private var snapshotsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Local Time Machine snapshots").font(.headline)
            Text("Copies Time Machine keeps on this disk between backups. They hold on to the space of files you have deleted since. macOS removes them on its own when space runs low; deleting them frees that space now. Backups on your backup disk are not affected.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.snapshots.isEmpty {
                Text("No local snapshots.").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.snapshots.enumerated()), id: \.element) { index, date in
                        if index > 0 { Divider() }
                        let path = LocalSnapshots.path(for: date)
                        HStack {
                            Toggle(isOn: Binding(
                                get: { model.ticked.contains(path) },
                                set: { on in
                                    if on { model.ticked.insert(path) } else { model.ticked.remove(path) }
                                }
                            )) {
                                Text(LocalSnapshots.displayDate(date)?.formatted(date: .abbreviated, time: .shortened) ?? date)
                            }
                            .toggleStyle(.checkbox)
                            .disabled(model.helperStatus != .ready)
                            Spacer()
                            SafetyBadge(level: .safe)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                }
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
                if model.helperStatus != .ready {
                    Text("Deleting snapshots needs the helper.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
