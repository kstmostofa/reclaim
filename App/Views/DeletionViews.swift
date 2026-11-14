import ReclaimCore
import SwiftUI

/// The bar under every list: what is ticked, and the one button that deletes it.
struct ActionBar: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let count = model.tickedItems.count
        HStack {
            Text(settings.moveToTrash ? "Ticked items move to the Trash." : "Ticked items are deleted permanently.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .layoutPriority(-1)
            Spacer()
            Button("Untick All") { model.untickAll() }
            Button {
                model.deleteTicked()
            } label: {
                Text("\(settings.moveToTrash ? "Move" : "Delete") \(count) \(count == 1 ? "item" : "items") · \(Format.size(model.tickedSize))")
                    .monospacedDigit()
                    .fixedSize()
            }
            .buttonStyle(.borderedProminent)
            .tint(settings.moveToTrash ? settings.accentColor : .red)
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(count == 0 || model.deletion != nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

/// Deleting, shown as a toast in the corner rather than a sheet: progress while it runs, then what was freed.
/// It closes by itself when everything went; when something could not be removed it stays, with Details.
struct DeletionToast: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        if let run = model.deletion {
            HStack(alignment: .center, spacing: 12) {
                badge(run)
                VStack(alignment: .leading, spacing: 3) {
                    if let report = run.report {
                        summary(report)
                    } else {
                        Text(settings.moveToTrash ? "Moving to Trash…" : "Deleting \(run.done) of \(run.total)…")
                            .font(.headline)
                            .monospacedDigit()
                        CapsuleProgress(value: Double(run.done) / Double(max(run.total, 1)), height: 5)
                            .frame(width: 220)
                        Text(abbreviated(run.current))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(width: 220, alignment: .leading)
                    }
                }
                if let report = run.report {
                    if !report.failures.isEmpty {
                        Button("Details") { model.showDeletionDetails = true }
                            .controlSize(.small)
                    }
                    Button {
                        model.dismissDeletion()
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Close")
                }
            }
            .padding(.vertical, 12)
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .modifier(ToastBackground())
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func badge(_ run: AppModel.DeletionRun) -> some View {
        let failed = !(run.report?.failures.isEmpty ?? true)
        return ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill((run.report == nil ? Color.accentColor : failed ? .orange : .green).opacity(0.16))
            if run.report == nil {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: failed ? "exclamationmark" : "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(failed ? .orange : .green)
            }
        }
        .frame(width: 32, height: 32)
    }

    @ViewBuilder private func summary(_ report: DeletionReport) -> some View {
        let removed = report.outcomes.count - report.failures.count
        Text(report.mode == .trash ? "Moved \(Format.size(report.freedBytes)) to the Trash" : "Freed \(Format.size(report.freedBytes))")
            .font(.headline)
        Text(report.failures.isEmpty
             ? "\(removed) \(removed == 1 ? "item" : "items") deleted"
             : "\(removed) deleted · \(report.failures.count) could not be removed")
            .font(.caption)
            .foregroundStyle(report.failures.isEmpty ? Color.secondary : Color.orange)
    }
}

/// Liquid Glass on macOS 26 and later, a material before that.
private struct ToastBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
        }
    }
}

/// What could not be removed, and why. Opened from the toast's Details button.
struct DeletionDetails: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let report = model.deletion?.report {
                Label("\(report.failures.count) items could not be removed", systemImage: "exclamationmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.orange)
                List(report.failures, id: \.item.path) { failure in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(abbreviated(failure.item.path)).lineLimit(1).truncationMode(.middle)
                        Text(failure.error ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 160, maxHeight: 320)
            }
            HStack {
                Spacer()
                Button("Done") {
                    model.showDeletionDetails = false
                    model.dismissDeletion()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}

/// A rounded progress bar in the accent colour, thicker than the system's linear style.
struct CapsuleProgress: View {
    let value: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(.tint)
                    .frame(width: max(height, geo.size.width * min(max(value, 0), 1)))
                    .animation(.smooth(duration: 0.4), value: value)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}
