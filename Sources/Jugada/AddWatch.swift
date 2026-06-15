import SwiftUI

/// The "Add a watch" flow — knight's friendly, no-typing-a-path way to watch any JSON API.
/// Paste a URL, knight fetches it and lists the numeric values it found; you click one
/// (which fills in the dot-path), choose a plain-language rule, name it, and Add. The result
/// is a `Watcher` written to `~/.jugada/config.json`.
///
/// Local-first: the only network call is the GET to the URL you paste (via
/// `GenericJSONConnector.fetchData`). Nothing else leaves the machine.
final class AddWatchModel: ObservableObject {
    @Published var urlString = ""
    @Published var fetching = false
    @Published var error: String?
    @Published var leaves: [JSONFlatten.Leaf] = []
    @Published var selectedPath: String?
    @Published var ruleType: RuleType = .above
    @Published var thresholdText = ""
    @Published var name = ""

    var onAdd: (Watcher) -> Void = { _ in }
    var onCancel: () -> Void = {}

    var selected: JSONFlatten.Leaf? { leaves.first { $0.path == selectedPath } }

    var canAdd: Bool {
        guard selected != nil, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if ruleType == .changes { return true }
        return Double(thresholdText) != nil
    }

    func fetch() async {
        // Read the input and reset state on main, then do the network off-main, then apply
        // results back on main — so @Published updates never fire from a background thread.
        let raw = await MainActor.run { () -> String in
            self.error = nil; self.leaves = []; self.selectedPath = nil; self.fetching = true
            return self.urlString
        }
        guard let url = normalizedURL(raw) else {
            await MainActor.run { self.error = "That doesn't look like a web link."; self.fetching = false }
            return
        }
        let data = await GenericJSONConnector.fetchData(from: url, headers: nil)
        await MainActor.run {
            self.fetching = false
            guard let data else {
                self.error = "Couldn't fetch that link — check the URL and that it returns JSON."
                return
            }
            let found = JSONFlatten.numericLeaves(from: data)
            if found.isEmpty { self.error = "No numeric values found in that response." }
            else { self.leaves = found; self.urlString = url.absoluteString }
        }
    }

    func select(_ leaf: JSONFlatten.Leaf) {
        selectedPath = leaf.path
        thresholdText = format(leaf.value)
        if name.isEmpty { name = leaf.label.split(separator: "›").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? leaf.label }
    }

    func add() {
        guard let leaf = selected else { return }
        let title = name.trimmingCharacters(in: .whitespaces)
        let watcher = Watcher(
            name: title,
            icon: nil,
            source: WatchSource(url: urlString, headers: nil, interval: nil),
            extract: Extract(path: leaf.path),
            rule: WatchRule(type: ruleType, value: ruleType == .changes ? nil : Double(thresholdText)),
            display: Display(title: title, detail: "{value}", link: nil)
        )
        onAdd(watcher)
    }

    func format(_ value: Double) -> String { value == value.rounded() ? String(Int(value)) : String(value) }

    private func normalizedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme), url.host != nil else { return nil }
        return url
    }
}

struct AddWatchView: View {
    @ObservedObject var model: AddWatchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add a watch")
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundColor(.jCream)

            // 1 — the link
            VStack(alignment: .leading, spacing: 6) {
                Text("Paste a link to the data (a JSON API)")
                    .font(.caption).foregroundColor(.jSage)
                HStack(spacing: 8) {
                    TextField("https://…", text: $model.urlString)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await model.fetch() } }
                    Button { Task { await model.fetch() } } label: {
                        Text(model.fetching ? "…" : "Fetch")
                    }
                    .disabled(model.fetching || model.urlString.isEmpty)
                }
                if let error = model.error {
                    Text(error).font(.caption).foregroundColor(.red)
                }
            }

            // 2 — click a value
            if !model.leaves.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Click the value to watch  ·  numbers only for now")
                        .font(.caption).foregroundColor(.jSage)
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(model.leaves, id: \.path) { leaf in
                                HStack {
                                    Text(leaf.label).foregroundColor(.jCream).lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text(model.format(leaf.value)).foregroundColor(.jSage).lineLimit(1)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 5)
                                    .fill(model.selectedPath == leaf.path ? Color.jGold.opacity(0.30) : Color.clear))
                                .contentShape(Rectangle())
                                .onTapGesture { model.select(leaf) }
                            }
                        }
                    }
                    .frame(maxHeight: 170)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.jBorder, lineWidth: 1))
                }
            }

            // 3 — the rule
            if model.selected != nil {
                Divider().overlay(Color.jBorder)
                Text("Notify me when this…").font(.caption).foregroundColor(.jSage)
                HStack(spacing: 8) {
                    Picker("", selection: $model.ruleType) {
                        Text("goes above").tag(RuleType.above)
                        Text("goes below").tag(RuleType.below)
                        Text("changes").tag(RuleType.changes)
                        Text("equals").tag(RuleType.equals)
                    }
                    .labelsHidden().frame(width: 150)
                    if model.ruleType != .changes {
                        TextField("value", text: $model.thresholdText)
                            .textFieldStyle(.roundedBorder).frame(width: 110)
                    }
                    Spacer()
                }
                TextField("Name (e.g. Bitcoin)", text: $model.name)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") { model.onCancel() }
                    Button("Add") { model.add() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!model.canAdd)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 420, height: 470, alignment: .topLeading)
        .background(Color.jBg)
        .tint(.jGold)
    }
}
