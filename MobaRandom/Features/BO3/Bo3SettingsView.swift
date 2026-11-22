import SwiftUI

struct Bo3SettingsView: View {
    let series: Bo3Series
    @Binding var poolText: String
    let onApply: (Bo3TeamNames, Bool, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftNames: Bo3TeamNames
    @State private var draftNoBan: Bool
    @State private var draftPoolText: String
    @State private var errorMessage: String?

    init(
        series: Bo3Series,
        poolText: Binding<String>,
        onApply: @escaping (Bo3TeamNames, Bool, String) -> Void
    ) {
        self.series = series
        _poolText = poolText
        self.onApply = onApply
        _draftNames = State(initialValue: series.teamNames)
        _draftNoBan = State(initialValue: series.noBanGame3)
        _draftPoolText = State(initialValue: poolText.wrappedValue)
    }

    private var pool: Bo3Pool {
        Bo3Pool(text: draftPoolText)
    }

    private var health: Bo3PoolHealth {
        Bo3DraftEngine.poolHealth(for: pool)
    }

    private var game3Started: Bool {
        series.games[2].started
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("队伍名称") {
                    TextField("红方队伍名称", text: $draftNames.a)
                        .textInputAutocapitalization(.never)
                    TextField("紫方队伍名称", text: $draftNames.b)
                        .textInputAutocapitalization(.never)
                    Text("留空时使用默认的 A 队 / B 队；最多保留 16 个字符。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    TextEditor(text: $draftPoolText)
                        .font(.body.monospaced())
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(
                            Color(uiColor: .tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                } header: {
                    Text("角色池")
                } footer: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(pool.categories.count) 个分类 · \(pool.total) 名角色")
                            .font(.caption)
                        Text(health.summary)
                            .font(.caption)
                            .foregroundStyle(health.canStartGame ? Color.secondary : Color.red)
                        if !pool.duplicates.isEmpty {
                            Text("已忽略重复：\(pool.duplicates.prefix(8).joined(separator: "、"))\(pool.duplicates.count > 8 ? " 等" : "")")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    Button("恢复默认角色池（34 人）") {
                        draftPoolText = GroupingEngine.defaultPoolText
                    }
                }

                Section {
                    Toggle("第 3 局不使用 BAN 位", isOn: $draftNoBan)
                    Text(
                        game3Started
                            ? "第 3 局已经开始，本设置将在下一场系列赛生效；当前第 3 局仍按开始时的赛制进行。"
                            : "决胜局只进行 8 手选用（双方各 4 选），不设禁用。适合角色池偏紧、前两局消耗较多的情况。"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("赛制")
                }

                Section {
                    Text("前序对局已选用的角色，本局不可再选；禁用不跨局继承，上一局被禁用的角色在下一局可以正常选用。同一局内，双方不能重复选择同一角色。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("全局 BP")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("BO3 设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        apply()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func apply() {
        guard pool.total >= Bo3DraftEngine.minimumPoolForGame else {
            errorMessage = "角色池至少需要 \(Bo3DraftEngine.minimumPoolForGame) 名不同角色，才能完成一局征召。"
            return
        }
        errorMessage = nil
        let names = Bo3DraftEngine.normalizedTeamNames(draftNames)
        onApply(names, draftNoBan, draftPoolText)
        dismiss()
    }
}
