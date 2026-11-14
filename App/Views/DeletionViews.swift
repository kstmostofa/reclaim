import ReclaimCore
import SwiftUI

/// The bar under every list: what is ticked, and the one button that deletes it.
struct ActionBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let count = model.tickedSuggestions.count
        HStack {
            Text(model.moveToTrash ? "Ticked items move to the Trash." : "Ticked items are deleted permanently.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Untick All") { model.untickAll() }
            Button {
                model.deleteTicked()
            } label: {
                Text("\(model.moveToTrash ? "Move" : "Delete") \(count) \(count == 1 ? "item" : "items") · \(Format.size(model.tickedSize))")
                    .monospacedDigit()
            }
            .buttonStyle(.borderedProminent)
            .tint(model.moveToTrash ? .accentColor : .red)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let run = model.deletion {
                if let report = run.report {
                    summary(report)
                } else {
                    Text(model.moveToTrash ? "Moving to Trash…" : "Deleting…").font(.headline)
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

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Toggle("Move to Trash instead of deleting permanently", isOn: $model.moveToTrash)
            Text("Permanent deletion frees space at once and cannot be undone. Moving to the Trash lets you change your mind, but frees nothing until the Trash is emptied.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding()
    }
}
