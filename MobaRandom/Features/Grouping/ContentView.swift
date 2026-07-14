import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage("moba_role_pool") private var rolePoolText = GroupingEngine.defaultPoolText

    @State private var lastGameText = ""
    @State private var allowDuplicate = false
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

            VStack(alignment: .leading, spacing: 8) {
                Text("上一局使用过的角色（选填）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if lastGameText.isEmpty {
                        Text("例如：温迪，胡桃，钟离，行秋")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $lastGameText)
                        .frame(minHeight: 84)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                        }
                }
            }

            HintText("填入上一局角色后，本次抽中它们的权重会降至其他角色的 1/10。")

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
            let newResult = try GroupingEngine.generate(
                poolText: rolePoolText,
                lastGameText: lastGameText,
                allowDuplicate: allowDuplicate
            )
            withAnimation(.easeOut(duration: 0.25)) {
                result = newResult
                swappedSlots = []
            }
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
        let candidates = GroupingEngine.replacementCandidates(
            for: currentResult,
            team: team,
            index: index,
            poolText: rolePoolText,
            allowDuplicate: allowDuplicate
        )

        guard let replacement = candidates.randomElement(),
              let updatedResult = currentResult.replacingRole(team: team, index: index, with: replacement) else {
            presentedError = PresentedError(
                title: "无法更换角色",
                message: "这个分路没有其他可用角色。请在角色池中补充角色，或开启镜像模式。"
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

    private static let historyKey = "moba_game_history_v1"
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
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(wasSwapped ? .white : color)
                        .frame(maxWidth: .infinity, minHeight: 44)
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
