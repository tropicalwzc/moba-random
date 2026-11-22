import SwiftUI

struct Bo3RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero

                    ruleSection("第 1 局：12 手顺序") {
                        flowGrid(Bo3DraftEngine.stepSequence)
                        Text("A 队先手。双方每局各 2 禁 4 选；同一局内，任何角色只能出现一次，两队也不能选到相同角色。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ruleSection("第 2 局：AB 对调") {
                        flowGrid(Bo3DraftEngine.game2StepSequence)
                        Text("第 2 局 A/B 全部对调：B 队先禁、先选，选人顺序整体镜像；双方仍各 2 禁 4 选。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ruleSection("第 3 局：无 BAN 选项") {
                        flowGrid(Bo3DraftEngine.game3NoBanSequence)
                        Text("默认开启「第 3 局不使用 BAN 位」。开启后第 3 局跳过全部禁用，进行 8 手选用（双方各 4 选），选人顺序与第 1 局一致。关闭后第 3 局恢复 12 手完整征召。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ruleSection("全局 BP") {
                        Text("只有前序对局已选用的角色会被锁定。例如第 1 局 A 队选用了温迪，第 2 局双方都不能再选用温迪；但第 1 局被禁用的角色，第 2 局可以正常选用。禁用只在当前对局内生效。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("第 3 局无 BAN 时，BO3 最多需要 24 名不同角色；关闭该选项则需要 28 名。当前默认角色池 34 名，两种赛制都足够完成 3 局。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ruleSection("推荐位置") {
                        Text("角色池中的「射手 / 打野 / 中路 / 战士」等分类只是推荐位置，不会限制选人。任何角色都可以在任何位置选用。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ruleSection("中断与重置") {
                        Text("本局结束后点击「进入下一局」继续系列赛。若比赛中途需要重新开始，使用「全局重置」清空比分与三局征召记录；角色池、队伍名称与赛制设置会保留。进度会自动保存在本机。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    attribution
                }
                .padding(18)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("比赛规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BO3 · 全局 BP")
                .font(.title3.bold())
                .foregroundStyle(Bo3Palette.goldInk.color)
            Text("共 3 局，先胜 2 局者赢得系列赛。每局单独征召；前序对局已选用的角色全局锁定，禁用每局重置。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Bo3Palette.gold.color.opacity(0.12),
                    Color(uiColor: .secondarySystemGroupedBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Bo3Palette.gold.color.opacity(0.25), lineWidth: 1)
        }
    }

    private var attribution: some View {
        VStack(alignment: .leading, spacing: 5) {
            Link("头像：原神观测枢", destination: URL(string: "https://baike.mihoyo.com/ys/obc/channel/map/189/25")!)
                .font(.caption.weight(.semibold))
            Text("本应用为非官方工具，与米哈游无关。角色头像仅用于本地阵容展示。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private func ruleSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Rectangle()
                    .fill(Bo3Palette.gold.color)
                    .frame(width: 3, height: 14)
                    .clipShape(Capsule())
                Text(title)
                    .font(.headline)
            }
            content()
        }
    }

    private func flowGrid(_ steps: [Bo3Step]) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
            spacing: 6
        ) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 3) {
                    Text(index + 1 < 10 ? "0\(index + 1)" : "\(index + 1)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("\(step.team.shortLabel)\(step.type.shortLabel)")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(
                            step.type == .ban
                                ? Color.red
                                : Bo3Palette.teamInkColor(step.team)
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                }
            }
        }
    }
}

#Preview {
    Bo3RulesView()
}
