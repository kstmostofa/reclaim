import ReclaimCore
import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: SidebarItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                storage
                scanSection
                if !model.categories.isEmpty {
                    topCategories
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Overview")
    }

    @ViewBuilder private var storage: some View {
        if let volume = model.volume {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(volume.name).font(.title2.weight(.semibold))
                    Spacer()
                    Text("\(Format.size(volume.available)) free of \(Format.size(volume.total))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                StorageBar(volume: volume, reclaimable: model.reclaimable)
                HStack(spacing: 18) {
                    legend(.primary.opacity(0.55), "Used", volume.used - min(model.reclaimable, volume.used))
                    legend(TintShapeStyle(), "Reclaimable", model.reclaimable)
                    legend(.secondary.opacity(0.18), "Free", volume.available)
                }
                .font(.callout)
            }
        }
    }

    private func legend(_ color: some ShapeStyle, _ title: String, _ bytes: Int64) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(title).foregroundStyle(.secondary)
            Text(Format.size(bytes)).monospacedDigit()
        }
    }

    @ViewBuilder private var scanSection: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 16) {
                switch model.phase {
                case .scanning:
                    ProgressView().controlSize(.small)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Scanning · \(Format.count(model.progress.files)) files · \(Format.size(model.progress.bytes))")
                            .monospacedDigit()
                        Text(model.progress.currentPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Stop") { model.cancelScan() }
                default:
                    VStack(alignment: .leading, spacing: 3) {
                        if let result = model.result {
                            Text("Last scan found \(Format.size(model.reclaimable)) you could reclaim, \(Format.size(model.safeReclaimable)) of it Safe.")
                            Text("\(Format.count(model.progress.files)) files in \(String(format: "%.0f", result.duration)) s, \(result.startedAt.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if result.unreadableFolders > 0 {
                                Text("\(Format.count(result.unreadableFolders)) folders could not be read. Give Reclaim Full Disk Access in System Settings › Privacy & Security to include them.")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        } else {
                            Text("Scan the disk to find caches, build output and leftovers you can delete.")
                        }
                        if let error = model.scanError {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                    }
                    Spacer()
                    Button(model.result == nil ? "Scan" : "Scan Again") { model.startScan() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
            .padding(8)
        }
    }

    private var topCategories: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top categories").font(.headline)
            VStack(spacing: 0) {
                ForEach(Array(model.categories.enumerated()), id: \.element.category) { index, entry in
                    if index > 0 { Divider() }
                    Button {
                        selection = .category(entry.category)
                    } label: {
                        HStack {
                            Image(systemName: entry.category.systemImage)
                                .frame(width: 22)
                                .foregroundStyle(.tint)
                            Text(entry.category.title)
                            Spacer()
                            Text("\(entry.count) items").foregroundStyle(.secondary)
                            Text(Format.size(entry.size))
                                .monospacedDigit()
                                .frame(minWidth: 80, alignment: .trailing)
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 9)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct StorageBar: View {
    let volume: VolumeInfo
    let reclaimable: Int64

    var body: some View {
        GeometryReader { geo in
            let total = max(Double(volume.total), 1)
            let reclaim = Double(min(reclaimable, volume.used))
            let used = Double(volume.used) - reclaim
            HStack(spacing: 0) {
                Rectangle().fill(.primary.opacity(0.55)).frame(width: geo.size.width * used / total)
                Rectangle().fill(.tint).frame(width: geo.size.width * reclaim / total)
                Rectangle().fill(.secondary.opacity(0.18))
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(height: 18)
        .accessibilityElement()
        .accessibilityLabel("Storage")
        .accessibilityValue("\(Format.size(volume.used)) used, \(Format.size(reclaimable)) reclaimable, \(Format.size(volume.available)) free")
    }
}
