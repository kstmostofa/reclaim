import AppKit
import ReclaimCore
import SwiftUI

/// The menu-bar window: free space at a glance, the last scan, and quick actions.
struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let volume = model.volume {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Format.size(volume.available)).font(.title2.weight(.semibold)).monospacedDigit()
                        Text("free").foregroundStyle(.secondary)
                        Spacer()
                        Text("of \(Format.size(volume.total))").foregroundStyle(.secondary).monospacedDigit()
                    }
                    StorageBar(volume: volume, reclaimable: model.result == nil ? (model.lastReclaimable ?? 0) : model.reclaimable)
                        .frame(height: 10)
                }
            }

            lastScan

            VStack(spacing: 6) {
                if model.phase == .scanning {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Scanning · \(Format.count(model.progress.files)) files").monospacedDigit()
                        Spacer()
                        Button("Stop") { model.cancelScan() }
                    }
                } else {
                    actionButton("Scan Now", systemImage: "magnifyingglass") { model.startScan() }
                }
                let safe = model.cleanableSafeItems
                actionButton(safe.isEmpty ? "Clean Safe Items" : "Clean Safe Items · \(Format.size(model.total(of: safe)))",
                             systemImage: "sparkles", prominent: !safe.isEmpty) {
                    Task { await model.cleanSafeItems() }
                }
                .disabled(safe.isEmpty || model.deletion != nil || model.phase == .scanning)
            }

            Divider()

            HStack {
                Button("Open Reclaim") {
                    openWindow(id: "main")
                    NSApp.activate()
                }
                Spacer()
                Button {
                    openSettings()
                    NSApp.activate()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .help("Quit Reclaim")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 300)
    }

    @ViewBuilder private var lastScan: some View {
        if model.result != nil {
            Text("\(Format.size(model.reclaimable)) reclaimable, \(Format.size(model.safeReclaimable)) of it Safe")
                .font(.callout)
        } else if let date = model.lastScanDate, let bytes = model.lastReclaimable {
            Text("\(Format.size(bytes)) reclaimable at the last scan, \(date.formatted(.relative(presentation: .named)))")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            Text("Not scanned yet").font(.callout).foregroundStyle(.secondary)
        }
    }

    private func actionButton(_ title: String, systemImage: String, prominent: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .buttonStyle(prominent ? AnyPrimitiveButtonStyle(.borderedProminent) : AnyPrimitiveButtonStyle(.bordered))
    }
}

/// Lets one call site pick between bordered styles.
struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: PrimitiveButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}
