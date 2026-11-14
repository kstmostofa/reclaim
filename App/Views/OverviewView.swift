import ReclaimCore
import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: SidebarItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                storage
                if !model.hasFullDiskAccess {
                    AccessBanner()
                }
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

    private var scanSection: some View {
        ScanCard()
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

/// Explains what a scan leaves out without Full Disk Access, and opens the setting.
struct AccessBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Reclaim can't see everything yet").font(.headline)
                Text("Without Full Disk Access, scans skip \(PrivacyAccess.promptingSummary), so macOS doesn't stop the scan to ask about each one. Turn on Reclaim in Full Disk Access, then scan again.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Open Settings") { model.openFullDiskAccessSettings() }
        }
        .padding(14)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.3)))
    }
}

/// The Overview's scan card: an invitation before the first scan, live progress while scanning, and the
/// findings afterwards.
struct ScanCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            badge
            VStack(alignment: .leading, spacing: 10) {
                switch model.phase {
                case .scanning: scanning
                default: model.result == nil ? AnyView(intro) : AnyView(findings)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            actions
        }
        .padding(20)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator.opacity(0.5)))
        .animation(.smooth, value: model.phase)
    }

    // MARK: Parts

    private var badge: some View {
        ZStack {
            Circle().fill(.tint.opacity(0.14))
            switch model.phase {
            case .scanning:
                ProgressView().controlSize(.regular)
            default:
                Image(systemName: model.result == nil ? "magnifyingglass" : "checkmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: 52, height: 52)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Find what you can delete").font(.title3.weight(.semibold))
            Text("Reclaim scans the disk for caches, build output, dependencies and leftovers, and explains each one before you delete anything.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            errorLine
        }
    }

    private var scanning: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Scanning…").font(.title3.weight(.semibold))
                Spacer()
                Text("about \(Int(estimate * 100))%").font(.callout).foregroundStyle(.secondary).monospacedDigit()
            }
            CapsuleProgress(value: estimate)
            HStack(spacing: 20) {
                Metric(value: Format.count(model.progress.files), label: "files")
                Metric(value: Format.size(model.progress.bytes), label: "read")
                Metric(value: Format.count(model.progress.folders), label: "folders")
            }
            Text(model.progress.currentPath.isEmpty ? " " : model.progress.currentPath)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    @ViewBuilder private var findings: some View {
        if let result = model.result {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Last scan").font(.title3.weight(.semibold))
                    Text(result.startedAt.formatted(.relative(presentation: .named)))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 28) {
                    Metric(value: Format.size(model.reclaimable), label: "reclaimable", prominent: true)
                    Metric(value: Format.size(model.safeReclaimable), label: "Safe to delete", tint: .green)
                    Metric(value: Format.count(model.progress.files), label: "files scanned")
                    Metric(value: "\(Int(result.duration.rounded())) s", label: "scan time")
                }
                if result.unreadableFolders > 0 && model.hasFullDiskAccess {
                    Label("\(Format.count(result.unreadableFolders)) folders could not be read, usually because they belong to macOS or another user.",
                          systemImage: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                errorLine
            }
        }
    }

    @ViewBuilder private var errorLine: some View {
        if let error = model.scanError {
            Label(error, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red)
        }
    }

    @ViewBuilder private var actions: some View {
        if model.phase == .scanning {
            Button("Stop") { model.cancelScan() }
                .controlSize(.large)
        } else {
            Button {
                model.startScan()
            } label: {
                Label(model.result == nil ? "Scan" : "Scan Again", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    /// A rough share of the disk read so far: bytes scanned against the volume's used space. A scan's total is
    /// unknown until it ends, so this is shown as an estimate.
    private var estimate: Double {
        guard let used = model.volume?.used, used > 0 else { return 0 }
        return min(0.99, Double(model.progress.bytes) / Double(used))
    }
}

/// A figure with a small label under it.
private struct Metric: View {
    let value: String
    let label: String
    var prominent = false
    var tint: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(prominent ? .title2.weight(.bold) : .title3.weight(.semibold))
                .foregroundStyle(tint.map(AnyShapeStyle.init) ?? (prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary)))
                .monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
