import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SensitiveSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var rules: [SensitiveRule]

    @AppStorage("sensitiveTTLSeconds") private var ttlSeconds: Double = 45
    @AppStorage("sensitiveEraseOnPaste") private var eraseOnPaste: Bool = true

    @State private var newProcessName: String = ""
    @State private var newDomain: String = ""

    private var appAndProcessRules: [SensitiveRule] {
        rules.filter { $0.kind != .domain }.sorted { $0.displayName < $1.displayName }
    }

    private var domainRules: [SensitiveRule] {
        rules.filter { $0.kind == .domain }.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        Form {
            Section {
                Text("Content copied while these apps, processes, or sites are active is stored encrypted and erased automatically \u{2014} useful for Tor Browser, password managers, and banking sites.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Auto-Erase") {
                Picker("Erase after", selection: $ttlSeconds) {
                    Text("15 seconds").tag(15.0)
                    Text("30 seconds").tag(30.0)
                    Text("45 seconds").tag(45.0)
                    Text("1 minute").tag(60.0)
                    Text("2 minutes").tag(120.0)
                    Text("5 minutes").tag(300.0)
                }
                .pickerStyle(.menu)

                Toggle("Erase immediately after pasting", isOn: $eraseOnPaste)
            }

            Section("Apps & Processes") {
                ForEach(appAndProcessRules) { rule in
                    ruleRow(rule)
                }
                Button {
                    addApp()
                } label: {
                    Label("Add App\u{2026}", systemImage: "plus")
                }
                HStack {
                    TextField("Process name (e.g. \"Terminal\")", text: $newProcessName)
                    Button("Add", action: addProcess)
                        .disabled(newProcessName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Sites") {
                ForEach(domainRules) { rule in
                    ruleRow(rule)
                }
                HStack {
                    TextField("Domain (e.g. \"mybank.com\")", text: $newDomain)
                    Button("Add", action: addDomain)
                        .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Text("First match in Safari or a Chrome-based browser prompts for one-time Automation permission so Clipbara can check the active tab's address.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func ruleRow(_ rule: SensitiveRule) -> some View {
        HStack {
            Image(systemName: icon(for: rule.kind))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(rule.displayName)
            Spacer()
            Button {
                remove(rule)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
        }
    }

    private func icon(for kind: SensitiveRuleKind) -> String {
        switch kind {
        case .app: return "app.badge"
        case .process: return "terminal"
        case .domain: return "globe"
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.title = "Select App"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier else { return }
        guard !rules.contains(where: { $0.kind == .app && $0.pattern == bundleId }) else { return }

        let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        modelContext.insert(SensitiveRule(kind: .app, pattern: bundleId, displayName: appName))
        save()
    }

    private func addProcess() {
        let name = newProcessName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty,
              !rules.contains(where: { $0.kind == .process && $0.pattern.caseInsensitiveCompare(name) == .orderedSame })
        else { return }
        modelContext.insert(SensitiveRule(kind: .process, pattern: name, displayName: name))
        newProcessName = ""
        save()
    }

    private func addDomain() {
        var domain = newDomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        domain = domain.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
        domain = domain.components(separatedBy: "/").first ?? domain
        guard !domain.isEmpty,
              !rules.contains(where: { $0.kind == .domain && $0.pattern == domain })
        else { return }
        modelContext.insert(SensitiveRule(kind: .domain, pattern: domain, displayName: domain))
        newDomain = ""
        save()
    }

    private func remove(_ rule: SensitiveRule) {
        modelContext.delete(rule)
        save()
    }

    private func save() {
        try? modelContext.save()
        appState.clipboardMonitor.loadSensitiveRules()
    }
}
