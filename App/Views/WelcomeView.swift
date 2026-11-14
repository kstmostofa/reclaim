import ReclaimCore
import SwiftUI

/// Shown once, on first launch: what deleting means in Reclaim, and how to let it see the whole disk.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Reclaim").font(.title2.weight(.bold))
                    Text("Before your first scan, two things to know.").foregroundStyle(.secondary)
                }
            }

            point(icon: "trash", tint: .red, title: "Deleting is immediate and permanent",
                  text: "Ticked items are deleted the moment you click Delete, with no “Are you sure?”. Only Safe items, which rebuild themselves, are ticked for you, and protected folders can never be deleted.")
            Toggle("Move to Trash instead, so I can change my mind", isOn: $settings.moveToTrash)
                .padding(.leading, 46)

            point(icon: "lock.shield", tint: .orange, title: "Full Disk Access lets Reclaim see everything",
                  text: "Without it, scans skip Desktop, Documents, Downloads and other apps' data. You can turn it on now or later from the Overview.")

            HStack {
                if !model.hasFullDiskAccess {
                    Button("Open Full Disk Access Settings") { model.openFullDiskAccessSettings() }
                }
                Spacer()
                Button("Continue") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
    }

    private func point(icon: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
