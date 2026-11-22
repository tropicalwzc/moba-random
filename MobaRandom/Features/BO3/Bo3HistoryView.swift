import SwiftUI

struct Bo3HistoryView: View {
    let series: Bo3Series
    @Environment(\.dismiss) private var dismiss

    private var priorGames: [(number: Int, game: Bo3Game)] {
        Array(series.games.prefix(max(0, series.currentGame - 1)))
            .enumerated()
            .map { (number: $0.offset + 1, game: $0.element) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if priorGames.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(priorGames.enumerated()), id: \.offset) { _, item in
                            gameCard(number: item.number, game: item.game)
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("系列赛记录")
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("暂无前序对局")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("从第 2 局开始，前序已选角色会在这里锁定；禁用每局重置。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    private func gameCard(number: Int, game: Bo3Game) -> some View {
        Bo3Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("G\(number)")
                        .font(.headline.monospaced())
                    Spacer()
                    Text(game.winner.map { "\(series.teamNames.name(for: $0)) 胜" } ?? "—")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(
                            game.winner.map(Bo3Palette.teamInkColor) ?? Color.secondary
                        )
                }

                teamRow(team: .a, game: game)
                Divider()
                teamRow(team: .b, game: game)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("第 \(number) 局，\(game.winner.map { "\(series.teamNames.name(for: $0)) 胜" } ?? "未判定")")
    }

    private func teamRow(team: Bo3Team, game: Bo3Game) -> some View {
        let actions = game.actions.filter { $0.team == team }
        let bans = actions.filter { $0.type == .ban }
        let picks = actions.filter { $0.type == .pick }
        let color = Bo3Palette.teamColor(team)
        let ink = Bo3Palette.teamInkColor(team)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Bo3TeamBadge(team: team, size: 22)
                Text(series.teamNames.name(for: team))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let winner = game.winner {
                    Text(winner == team ? "胜" : "负")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(winner == team ? ink : Color.secondary)
                }
            }

            slotRow(label: "BAN", actions: bans, capacity: 2, team: team, color: color)
            slotRow(label: "PICK", actions: picks, capacity: 4, team: team, color: color)
        }
    }

    private func slotRow(
        label: String,
        actions: [Bo3Action],
        capacity: Int,
        team: Bo3Team,
        color: Color
    ) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            ForEach(0..<capacity, id: \.self) { index in
                if index < actions.count {
                    HStack(spacing: 3) {
                        Bo3AvatarView(name: actions[index].hero, size: 20)
                        Text(actions[index].hero)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.09), in: Capsule())
                    .accessibilityLabel("\(team.sideLabel)\(label) \(actions[index].hero)")
                } else {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(
                            Color.secondary.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                        )
                        .frame(width: 34, height: 20)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
