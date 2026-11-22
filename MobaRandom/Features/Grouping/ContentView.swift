import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage("moba_role_pool") private var rolePoolText = GroupingEngine.defaultPoolText
    @AppStorage("moba_role_weights_v1") private var roleWeightJSON = ""

    @State private var allowDuplicate = false
    @State private var avoidsPreviousResult = false
    @State private var previousRolesText = ""
    @State private var result: GroupingResult?
    @State private var swappedSlots: Set<RoleSlot> = []
    @State private var history: [GameHistoryEntry] = []
    @State private var currentHistoryID: UUID?
    @State private var presentedError: PresentedError?
    @State private var isShowingResetConfirmation = false
    @State private var isShowingClearHistoryConfirmation = false
    @State private var copied = false
    @State private var hasGeneratedInitialResult = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        rolePoolSection
                        rulesSection

                        if let result {
                            resultSection(result)
                                .id("result")
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        if !history.isEmpty {
                            historySection
                        }
                    }
                    .frame(maxWidth: 760)
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Color(uiColor: .systemGroupedBackground))
                .onAppear {
                    guard !hasGeneratedInitialResult else { return }
                    hasGeneratedInitialResult = true
                    if rolePoolText.isEmpty {
                        rolePoolText = GroupingEngine.defaultPoolText
                    }
                    loadHistory()
                    generate(recordInHistory: false)
                }
                .onChange(of: result) {
                    guard result != nil else { return }
                    withAnimation(.easeOut(duration: 0.35)) {
                        proxy.scrollTo("result", anchor: .bottom)
                    }
                }
            }
            .navigationTitle("分组助手")
            .navigationBarTitleDisplayMode(.inline)
        }
        .confirmationDialog(
            "恢复默认角色池？",
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("恢复默认", role: .destructive) {
                rolePoolText = GroupingEngine.defaultPoolText
                generate()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("当前的自定义设置将会丢失。")
        }
        .confirmationDialog(
            "清空全部历史记录？",
            isPresented: $isShowingClearHistoryConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空历史", role: .destructive) {
                history = []
                currentHistoryID = nil
                persistHistory()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("最多保存的 100 局记录将被永久删除。")
        }
        .alert(item: $presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("好"))
            )
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.blue.gradient)
                .accessibilityHidden(true)

            Text("MOBA 分组助手 Pro")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("动态角色池 · 智能避让上一局 · 毫秒级随机")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 4)
    }

    private var rolePoolSection: some View {
        AppSection {
            HStack {
                Label("角色池设置", systemImage: "person.3.sequence.fill")
                    .font(.headline)
                Spacer()
                Button("恢复默认") {
                    isShowingResetConfirmation = true
                }
                .font(.subheadline)
            }

            TextEditor(text: $rolePoolText)
                .font(.body.monospaced())
                .frame(minHeight: 170)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                }
                .accessibilityLabel("角色池")

            HintText("支持自定义职业名称；角色之间可用顿号、逗号或空格分隔。修改会自动保存。")

            NavigationLink {
                let scannedConfiguration = currentWeightConfiguration()
                RoleWeightSettingsView(
                    poolText: rolePoolText,
                    configuration: scannedConfiguration,
                    onSave: persistRoleWeights,
                    onImport: { importedPoolText, importedConfiguration in
                        rolePoolText = importedPoolText
                        persistRoleWeights(importedConfiguration)
                    }
                )
                .onAppear { persistRoleWeights(scannedConfiguration) }
            } label: {
                Label("设置分路权重", systemImage: "chart.bar.xaxis")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var rulesSection: some View {
        AppSection {
            Label("分组规则", systemImage: "slider.horizontal.3")
                .font(.headline)

            Toggle(isOn: $allowDuplicate) {
                HStack(spacing: 8) {
                    Text("允许两组使用相同角色")
                    if allowDuplicate {
                        Text("镜像模式")
                            .font(.caption2.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.orange, in: Capsule())
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: allowDuplicate)

            HintText("开启后，A/B 两组会独立抽取，各分路可能使用同一个角色。")

            Divider()

            Toggle("降低上一轮角色的抽中概率", isOn: $avoidsPreviousResult)
            HintText("开启后，应用会自动识别上一轮分组中的角色，并将它们下一轮的有效权重降至 1/10。")

            if result == nil {
                Button {
                    generate()
                } label: {
                    Label("开始随机分组", systemImage: "dice.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private func resultSection(_ result: GroupingResult) -> some View {
        AppSection {
            HStack {
                Label("分组结果", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
                Button {
                    copyResult(result)
                } label: {
                    Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(copied ? .green : .blue)
            }

            Text("种子：\(result.seed)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .trailing)

            TeamResultView(
                title: "Group A",
                color: .blue,
                players: result.playersA,
                roles: result.rolesA,
                team: .a,
                swappedSlots: swappedSlots,
                onRoleTapped: swapRole
            )

            TeamResultView(
                title: "Group B",
                color: .orange,
                players: result.playersB,
                roles: result.rolesB,
                team: .b,
                swappedSlots: swappedSlots,
                onRoleTapped: swapRole
            )

            HintText("点按任意角色，可在同一分路的其他角色中随机更换。紫色角色表示本局已更换。")

            Button {
                generate()
            } label: {
                Label("再次随机分组", systemImage: "dice.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var historySection: some View {
        AppSection {
            HStack {
                Label("历史记录", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                Text("\(history.count)/\(GroupingEngine.historyLimit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("清空", role: .destructive) {
                    isShowingClearHistoryConfirmation = true
                }
                .font(.subheadline)
            }

            LazyVStack(spacing: 10) {
                ForEach(history) { entry in
                    HistoryRow(entry: entry)
                }
            }
        }
    }

    private func generate(recordInHistory: Bool = true) {
        do {
            let weights = currentWeightConfiguration()
            persistRoleWeights(weights)
            let precedingRolesText = GroupingEngine.previousRolesText(from: result)
            let newResult = try GroupingEngine.generate(
                poolText: rolePoolText,
                lastGameText: avoidsPreviousResult ? precedingRolesText : "",
                allowDuplicate: allowDuplicate,
                weightConfiguration: weights
            )
            withAnimation(.easeOut(duration: 0.25)) {
                result = newResult
                swappedSlots = []
            }
            previousRolesText = precedingRolesText
            currentHistoryID = nil
            if recordInHistory {
                record(result: newResult, swappedSlots: [])
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            presentedError = PresentedError(title: "无法生成分组", message: message)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func swapRole(team: ResultTeam, index: Int) {
        guard let currentResult = result else { return }
        let weights = currentWeightConfiguration()
        persistRoleWeights(weights)
        let replacement = GroupingEngine.replacementRole(
            for: currentResult,
            team: team,
            index: index,
            poolText: rolePoolText,
            lastGameText: avoidsPreviousResult ? previousRolesText : "",
            allowDuplicate: allowDuplicate,
            weightConfiguration: weights
        )

        guard let replacement,
              let updatedResult = currentResult.replacingRole(team: team, index: index, with: replacement) else {
            presentedError = PresentedError(
                title: "无法更换角色",
                message: "这个分路没有其他权重大于 0 的可用角色。请调整分路权重、补充角色，或开启镜像模式。"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        let slot = RoleSlot(team: team, index: index)
        var updatedSlots = swappedSlots
        updatedSlots.insert(slot)
        withAnimation(.snappy(duration: 0.25)) {
            result = updatedResult
            swappedSlots = updatedSlots
        }
        updateHistory(with: updatedResult, swappedSlots: updatedSlots)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func copyResult(_ result: GroupingResult) {
        UIPasteboard.general.string = result.formattedText
        copied = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    private func record(result: GroupingResult, swappedSlots: Set<RoleSlot>) {
        let entry = GameHistoryEntry(result: result, swappedSlots: swappedSlots)
        history.insert(entry, at: 0)
        history = GroupingEngine.limitedHistory(history)
        currentHistoryID = entry.id
        persistHistory()
    }

    private func updateHistory(with result: GroupingResult, swappedSlots: Set<RoleSlot>) {
        if let currentHistoryID,
           let index = history.firstIndex(where: { $0.id == currentHistoryID }) {
            history[index].result = result
            history[index].swappedSlots = swappedSlots
        } else {
            record(result: result, swappedSlots: swappedSlots)
            return
        }
        persistHistory()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: Self.historyKey),
              let savedHistory = try? JSONDecoder().decode([GameHistoryEntry].self, from: data) else {
            return
        }
        history = GroupingEngine.limitedHistory(savedHistory)
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyKey)
    }

    private func currentWeightConfiguration() -> RoleWeightConfiguration {
        let saved = roleWeightJSON.data(using: .utf8).flatMap {
            try? JSONDecoder().decode(RoleWeightConfiguration.self, from: $0)
        }
        let categories = GroupingEngine.parseRolePool(rolePoolText)
        return RoleWeightConfiguration.reconciled(categories: categories, saved: saved)
    }

    private func persistRoleWeights(_ configuration: RoleWeightConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration),
              let encoded = String(data: data, encoding: .utf8) else { return }
        roleWeightJSON = encoded
    }

    private static let historyKey = "moba_game_history_v1"
}

private struct RoleWeightSettingsView: View {
    private struct FieldID: Hashable {
        let character: String
        let lane: String
    }

    private struct TransferNotice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FieldID?

    let onSave: (RoleWeightConfiguration) -> Void
    let onImport: (String, RoleWeightConfiguration) -> Void

    @State private var activePoolText: String
    @State private var configuration: RoleWeightConfiguration
    @State private var draft: [String: [String: String]]
    @State private var isShowingDiscardConfirmation = false
    @State private var transferNotice: TransferNotice?

    private var categories: [RoleCategory] { GroupingEngine.parseRolePool(activePoolText) }
    private var lanes: [String] { categories.map(\.name) }
    private var characters: [String] { configuration.characters.map(\.character) }

    init(
        poolText: String,
        configuration: RoleWeightConfiguration,
        onSave: @escaping (RoleWeightConfiguration) -> Void,
        onImport: @escaping (String, RoleWeightConfiguration) -> Void
    ) {
        self.onSave = onSave
        self.onImport = onImport
        _activePoolText = State(initialValue: poolText)
        _configuration = State(initialValue: configuration)
        _draft = State(initialValue: Self.makeDraft(
            configuration: configuration,
            lanes: GroupingEngine.parseRolePool(poolText).map(\.name)
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                AppSection {
                    Label("每个角色的整数权重合计必须为 100。提交后若超过 100，会按当前比例自动换算。", systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 288, maximum: 420), spacing: 12)],
                    alignment: .center,
                    spacing: 12
                ) {
                    ForEach(characters, id: \.self) { character in
                        characterCard(character)
                    }
                }
            }
            .frame(maxWidth: 1_400)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("分路权重")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("返回") { attemptDismiss() }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("导出到剪切板", systemImage: "doc.on.clipboard") { exportJSON() }
                    Button("从剪切板导入", systemImage: "clipboard") { importJSON() }
                } label: {
                    Label("JSON", systemImage: "arrow.up.arrow.down")
                }

                Button("保存") { save() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
        .onChange(of: focusedField) { oldValue, _ in
            if let oldValue { commitRow(oldValue.character) }
        }
        .confirmationDialog(
            "放弃未完成的权重设置？",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("放弃修改", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("存在合计不足 100 或无效的角色权重，无法保存。")
        }
        .alert(item: $transferNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("好"))
            )
        }
    }

    private func characterCard(_ character: String) -> some View {
        let total = rowValues(character)?.reduce(0, +)
        return AppSection {
            HStack {
                Text(character)
                    .font(.headline)
                Spacer()
                if let total {
                    Text(total == 100 ? "100 / 100" : "还差 \(max(0, 100 - total))")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(total == 100 ? .green : .orange)
                } else {
                    Text("请输入整数")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(lanes, id: \.self) { lane in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(lane)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("0", text: binding(character: character, lane: lane))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)
                                .frame(width: 56)
                                .focused($focusedField, equals: FieldID(character: character, lane: lane))
                                .onSubmit { commitRow(character) }
                                .accessibilityLabel("\(character) \(lane)权重")
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var canSave: Bool {
        characters.allSatisfy { character in
            guard let values = rowValues(character) else { return false }
            return values.reduce(0, +) >= 100
        }
    }

    private var hasInvalidDraft: Bool {
        characters.contains { character in
            guard let values = rowValues(character) else { return true }
            return values.reduce(0, +) != 100
        }
    }

    private func binding(character: String, lane: String) -> Binding<String> {
        Binding(
            get: { draft[character]?[lane] ?? "0" },
            set: { value in
                let digits = value.filter(\.isNumber)
                draft[character, default: [:]][lane] = digits
            }
        )
    }

    private func rowValues(_ character: String) -> [Int]? {
        var values: [Int] = []
        for lane in lanes {
            guard let raw = draft[character]?[lane], !raw.isEmpty, let value = Int(raw), value >= 0 else {
                return nil
            }
            values.append(value)
        }
        return values
    }

    private func commitRow(_ character: String) {
        guard let values = rowValues(character),
              let normalized = RoleWeightConfiguration.normalizedToHundred(values) else { return }
        for (index, lane) in lanes.enumerated() {
            draft[character, default: [:]][lane] = String(normalized[index])
        }
    }

    private func save() {
        characters.forEach(commitRow)
        guard let updatedConfiguration = draftConfiguration() else { return }
        onSave(updatedConfiguration)
        dismiss()
    }

    private func draftConfiguration() -> RoleWeightConfiguration? {
        guard !hasInvalidDraft else { return nil }
        let entries = characters.compactMap { character -> CharacterLaneWeights? in
            guard let values = rowValues(character) else { return nil }
            return CharacterLaneWeights(
                character: character,
                laneWeights: Dictionary(uniqueKeysWithValues: zip(lanes, values)),
                sourceLane: configuration.characters.first(where: { $0.character == character })?.sourceLane
            )
        }
        guard entries.count == characters.count else { return nil }
        return RoleWeightConfiguration(characters: entries)
    }

    private func exportJSON() {
        focusedField = nil
        characters.forEach(commitRow)
        guard let updatedConfiguration = draftConfiguration() else {
            transferNotice = TransferNotice(
                title: "无法导出",
                message: "请先让每个角色的权重合计为 100。"
            )
            return
        }
        do {
            UIPasteboard.general.string = try RoleWeightTransfer.exportJSON(
                lanes: lanes,
                configuration: updatedConfiguration
            )
            transferNotice = TransferNotice(title: "已导出", message: "权重 JSON 已复制到剪切板。")
        } catch {
            transferNotice = TransferNotice(title: "无法导出", message: error.localizedDescription)
        }
    }

    private func importJSON() {
        focusedField = nil
        guard let json = UIPasteboard.general.string, !json.isEmpty else {
            transferNotice = TransferNotice(title: "无法导入", message: "剪切板中没有文本。")
            return
        }
        do {
            let imported = try RoleWeightTransfer.importJSON(json, currentLanes: lanes)
            activePoolText = imported.poolText
            configuration = imported.configuration
            draft = Self.makeDraft(
                configuration: imported.configuration,
                lanes: GroupingEngine.parseRolePool(imported.poolText).map(\.name)
            )
            onImport(imported.poolText, imported.configuration)
            transferNotice = TransferNotice(
                title: "导入成功",
                message: "权重设置与主页角色池已按最新 JSON 更新。"
            )
        } catch {
            transferNotice = TransferNotice(title: "无法导入", message: error.localizedDescription)
        }
    }

    private func attemptDismiss() {
        focusedField = nil
        if hasInvalidDraft {
            isShowingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private static func makeDraft(
        configuration: RoleWeightConfiguration,
        lanes: [String]
    ) -> [String: [String: String]] {
        Dictionary(uniqueKeysWithValues: configuration.characters.map { entry in
            (
                entry.character,
                Dictionary(uniqueKeysWithValues: lanes.map { lane in
                    (lane, String(entry.laneWeights[lane] ?? 0))
                })
            )
        })
    }
}

private struct AppSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
    }
}

private struct HintText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label(text, systemImage: "lightbulb")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct TeamResultView: View {
    let title: String
    let color: Color
    let players: [Int]
    let roles: [String]
    let team: ResultTeam
    let swappedSlots: Set<RoleSlot>
    let onRoleTapped: (ResultTeam, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(color)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(players, id: \.self) { player in
                        Text("\(player)")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(color)
                            .frame(minWidth: 42, minHeight: 42)
                            .background(color.opacity(0.13), in: Circle())
                            .overlay {
                                Circle().stroke(color.opacity(0.28), lineWidth: 1)
                            }
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
            .accessibilityLabel("玩家 \(players.map(String.init).joined(separator: "，"))")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(Array(roles.enumerated()), id: \.offset) { index, role in
                    let wasSwapped = swappedSlots.contains(RoleSlot(team: team, index: index))
                    Button {
                        onRoleTapped(team, index)
                    } label: {
                        HStack(spacing: 6) {
                            if wasSwapped {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption2.bold())
                            }
                            Text(role)
                                .font(.system(size: 19, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .allowsTightening(true)
                        }
                        .foregroundStyle(wasSwapped ? .white : color)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .padding(.horizontal, 10)
                        .background(
                            wasSwapped ? Color.purple : color.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    wasSwapped ? Color.purple : color.opacity(0.35),
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(role)")
                    .accessibilityHint("点按后随机更换为同一分路的其他角色")
                }
            }
        }
        .padding(16)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 10)
        }
    }
}

private struct HistoryRow: View {
    let entry: GameHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("种子 \(entry.result.seed)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            historyTeam(
                name: "A",
                players: entry.result.playersA,
                roles: entry.result.rolesA,
                team: .a,
                color: .blue
            )
            historyTeam(
                name: "B",
                players: entry.result.playersB,
                roles: entry.result.rolesB,
                team: .b,
                color: .orange
            )
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func historyTeam(
        name: String,
        players: [Int],
        roles: [String],
        team: ResultTeam,
        color: Color
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name)
                .font(.caption.bold())
                .foregroundStyle(color)
                .frame(width: 14)
            Text(players.map(String.init).joined(separator: "，"))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(roles.enumerated().map { index, role in
                entry.swappedSlots.contains(RoleSlot(team: team, index: index)) ? "↻\(role)" : role
            }.joined(separator: "，"))
                .font(.caption.weight(.medium))
                .foregroundStyle(
                    entry.swappedSlots.contains(where: { $0.team == team }) ? Color.purple : Color.primary
                )
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}

private struct PresentedError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview("iPhone") {
    ContentView()
}

#Preview("iPad", traits: .fixedLayout(width: 1024, height: 1366)) {
    ContentView()
}
