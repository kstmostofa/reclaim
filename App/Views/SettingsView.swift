import ReclaimCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    /// `-settingsTab scanning` on the command line opens that tab; used for screenshots.
    @State private var tab = UserDefaults.standard.string(forKey: "settingsTab") ?? "general"

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag("general")
            ScanSettings()
                .tabItem { Label("Scanning", systemImage: "magnifyingglass") }
                .tag("scanning")
            AppearanceSettings()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
                .tag("appearance")
        }
        .frame(width: 520)
    }
}

private struct GeneralSettings: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Toggle("Move to Trash instead of deleting permanently", isOn: $settings.moveToTrash)
            } footer: {
                Text("Permanent deletion frees space at once and cannot be undone. Moving to the Trash lets you change your mind, but frees nothing until the Trash is emptied.")
                    .settingsFootnote()
            }
            Section {
                Toggle("Tick Safe items after each scan", isOn: $settings.preselectSafe)
            } footer: {
                Text("Safe items rebuild themselves, such as build caches and app caches. Rebuild and Personal items are never ticked for you.")
                    .settingsFootnote()
            }
            Section {
                HStack {
                    Spacer()
                    Button("Restore Default Settings") { settings.resetToDefaults() }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ScanSettings: View {
    @Environment(AppSettings.self) private var settings
    @State private var selectedFolder: String?
    @State private var pickingFolder = false

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker("Scan", selection: $settings.scanScope) {
                    ForEach(AppSettings.ScanScope.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.radioGroup)
            } footer: {
                Text("Scanning the whole disk also finds caches and leftovers outside your home folder. Both take effect at the next scan.")
                    .settingsFootnote()
            }
            Section("Thresholds") {
                Stepper(value: $settings.largeFileThresholdMB, in: 50...50_000, step: 50) {
                    LabeledContent("Large files from", value: "\(settings.largeFileThresholdMB) MB")
                }
                Stepper(value: $settings.downloadsAgeDays, in: 7...3650, step: 7) {
                    LabeledContent("Old downloads after", value: "\(settings.downloadsAgeDays) days")
                }
                Stepper(value: $settings.duplicateMinimumMB, in: 1...1000) {
                    LabeledContent("Compare duplicates from", value: "\(settings.duplicateMinimumMB) MB")
                }
            }
            Section {
                List(selection: $selectedFolder) {
                    ForEach(settings.excludedFolders, id: \.self) { path in
                        Label(abbreviated(path), systemImage: "folder").tag(path)
                    }
                }
                .frame(minHeight: 90)
                .overlay {
                    if settings.excludedFolders.isEmpty {
                        Text("No excluded folders").foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button("Add Folder…") { pickingFolder = true }
                    Button("Remove") {
                        settings.excludedFolders.removeAll { $0 == selectedFolder }
                        selectedFolder = nil
                    }
                    .disabled(selectedFolder == nil)
                }
            } header: {
                Text("Never scan these folders")
            } footer: {
                Text("Excluded folders are neither measured nor suggested, so nothing inside them can be deleted from Reclaim.")
                    .settingsFootnote()
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            for url in urls where !settings.excludedFolders.contains(url.path) {
                settings.excludedFolders.append(url.path)
            }
        }
    }
}

private struct AppearanceSettings: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppSettings.Appearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                LabeledContent("Accent color") {
                    HStack(spacing: 8) {
                        ForEach(AppSettings.Accent.allCases.filter { $0 != .custom }) { accent in
                            Swatch(color: accent.color ?? .indigo, isSelected: settings.accent == accent)
                                .onTapGesture { settings.accent = accent }
                                .help(accent.title)
                                .accessibilityLabel(accent.title)
                                .accessibilityAddTraits(settings.accent == accent ? .isSelected : [])
                        }
                    }
                }
                LabeledContent("Custom color") {
                    HStack {
                        if settings.accent == .custom {
                            Text(settings.customAccentHex).monospaced().foregroundStyle(.secondary)
                        }
                        ColorPicker("Custom color", selection: Binding(
                            get: { settings.customAccent },
                            set: {
                                settings.customAccent = $0
                                settings.accent = .custom
                            }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                }
            } footer: {
                Text("Used for buttons, selections and the reclaimable part of the storage bar. Indigo is the default.")
                    .settingsFootnote()
            }
            Section("Preview") {
                HStack(spacing: 12) {
                    Button("Scan") {}.buttonStyle(.borderedProminent)
                    Toggle("Ticked", isOn: .constant(true)).toggleStyle(.checkbox)
                    ProgressView(value: 0.6).frame(width: 120)
                    SafetyBadge(level: .safe)
                    SafetyBadge(level: .rebuild)
                    SafetyBadge(level: .personal)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct Swatch: View {
    let color: Color
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 18, height: 18)
            .overlay {
                if isSelected {
                    Circle().fill(.white).frame(width: 6, height: 6)
                }
            }
            .overlay(Circle().strokeBorder(.primary.opacity(0.15)))
            .contentShape(Circle())
    }
}

private extension Text {
    func settingsFootnote() -> some View {
        font(.caption).foregroundStyle(.secondary)
    }
}
