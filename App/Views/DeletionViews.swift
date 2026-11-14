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

/// Live progress while deleting, then the summary.
struct DeletionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let run = model.deletion {
                if let report = run.report {
                    summary(report)
                } else {
                    Text(settings.moveToTrash ? "Moving to Trash…" : "Deleting…").font(.headline)
                    ProgressView(value: Double(run.done), total: Double(max(run.total, 1)))
                    Text("\(run.done) of \(run.total) · \(abbreviated(run.current))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    @ViewBuilder private func summary(_ report: DeletionReport) -> some View {
        let failures = report.failures
        let succeeded = report.outcomes.count - failures.count
        Label(report.mode == .trash ? "Moved \(Format.size(report.freedBytes)) to the Trash"
                                    : "Freed \(Format.size(report.freedBytes))",
              systemImage: failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .font(.title2.weight(.semibold))
            .foregroundStyle(failures.isEmpty ? .green : .orange)
        Text("\(succeeded) of \(report.outcomes.count) items removed.")
            .foregroundStyle(.secondary)
        if !failures.isEmpty {
            Text("Not removed").font(.headline)
            List(failures, id: \.item.path) { failure in
                VStack(alignment: .leading, spacing: 2) {
                    Text(abbreviated(failure.item.path)).lineLimit(1).truncationMode(.middle)
                    Text(failure.error ?? "").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 120, maxHeight: 260)
        }
        HStack {
            Spacer()
            Button("Done") { model.dismissDeletion() }
                .keyboardShortcut(.defaultAction)
        }
    }
}
