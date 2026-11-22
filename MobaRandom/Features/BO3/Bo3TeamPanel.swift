import SwiftUI

struct Bo3TeamPanel: View {
    let series: Bo3Series
    let team: Bo3Team
    let isActive: Bool

    private var game: Bo3Game? {
        series.activeGame
    }

    private var teamActions: [Bo3Action] {
        game?.actions.filter { $0.team == team } ?? []
    }

    private var bans: [Bo3Action] {
        teamActions.filter { $0.type == .ban }
    }

    private var picks: [Bo3Action] {
        teamActions.filter { $0.type == .pick }
    }

    private var wins: Int {
        team == .a ? series.wins.a : series.wins.b
    }

    private var color: Color {
        Bo3Palette.teamColor(team)
    }

    private var ink: Color {
        Bo3Palette.teamInkColor(team)
    }

    private var isChampion: Bool {
        series.champion == team
    }

    private var isNoBan: Bool {
        guard series.currentGame == 3 else { return false }
        if let game, game.started {
            return game.noBan
        }
        return series.noBanGame3
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                currentGameSection
                priorGamesSection
            }
            .padding(14)
        }
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isActive ? color.opacity(0.65) : Color.secondary.opacity(0.1),
                    lineWidth: isActive ? 2 : 1
                )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("\(team.sideLabel) · \(team == .a ? "RED" : "PURPLE")")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(ink)
                Spacer()
                if isChampion {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Bo3Palette.gold.color)
                }
                Bo3WinPips(wins: wins, team: team)
            }

            Text(series.teamNames.name(for: team))
                .font(.title2.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            seatRow
        }
        .accessibilityElement(children: .combine)
    }

    private var seatRow: some View {
        let seats = team == .a ? series.seats?.a : series.seats?.b
        return HStack(spacing: 4) {
            Image(systemName: "chair.lounge.fill")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            if let seats, seats.count == 4 {
                ForEach(seats, id: \.self) { seat in
                    Text("\(seat)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(
                            Color(uiColor: .tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                }
            } else {
                Text("待抽签")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var currentGameSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionHeader(
                "第 \(max(1, series.currentGame)) 局",
                trailing: game?.winner.map { winner in
                    winner == team ? "胜" : "负"
                } ?? "—"
            )

            if series.currentGame == 0 {
                Text("开始一局比赛后显示本局阵容。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if isNoBan {
                    HStack(spacing: 6) {
                        Image(systemName: "nosign")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text("本局无 BAN，直接进行 8 手选用")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color(uiColor: .tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                } else {
                    Text("禁用 · \(bans.count) / 2")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                    ForEach(0..<2, id: \.self) { index in
                        slotRow(
                            action: value(in: bans, at: index),
                            kind: .ban,
                            emptyText: "待禁用"
                        )
                    }
                }

                Text("选用 · \(picks.count) / 4")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
                ForEach(0..<4, id: \.self) { index in
                    slotRow(
                        action: value(in: picks, at: index),
                        kind: .pick,
                        emptyText: "待选用"
                    )
                }
            }
        }
    }

    private var priorGamesSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionHeader("前序对局", trailing: "\(max(0, series.currentGame - 1)) 局")

            let prior = Array(series.games.prefix(max(0, series.currentGame - 1)))
            if prior.isEmpty {
                Text("前序已选角色会在这里锁定；禁用每局重置。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(prior.enumerated()), id: \.offset) { index, priorGame in
                    priorGameRow(index: index, game: priorGame)
                }
            }
        }
    }

    private func priorGameRow(index: Int, game: Bo3Game) -> some View {
        let gameBans = game.actions.filter { $0.team == team && $0.type == .ban }
        let gamePicks = game.actions.filter { $0.team == team && $0.type == .pick }
        let result = game.winner.map { $0 == team ? "胜" : "负" } ?? "—"

        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("G\(index + 1)")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                Text(result)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(result == "胜" ? ink : Color.secondary)
                Spacer()
            }
            chipRow(label: "BAN", actions: gameBans, color: color)
            chipRow(label: "PICK", actions: gamePicks, color: color)
        }
        .padding(9)
        .background(
            Color(uiColor: .tertiarySystemFill),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private func chipRow(label: String, actions: [Bo3Action], color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.secondary)
            if actions.isEmpty {
                Text("—")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                    Text(action.hero)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.12), in: Capsule())
                        .foregroundStyle(ink)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func slotRow(action: Bo3Action?, kind: Bo3ActionType, emptyText: String) -> some View {
        if let action {
            HStack(spacing: 9) {
                Bo3AvatarView(name: action.hero, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.hero)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text("推荐 \(action.role.isEmpty ? "未知" : action.role)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(kind.shortLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(color.opacity(0.1), in: Capsule())
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(team.sideLabel)\(kind.label) \(action.hero)，推荐位置 \(action.role)")
        } else {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        Color.secondary.opacity(0.25),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
                    .frame(width: 38, height: 38)
                    .overlay {
                        Text(kind.shortLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                Text(emptyText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private func sectionHeader(_ title: String, trailing: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(trailing)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func value(in list: [Bo3Action], at index: Int) -> Bo3Action? {
        list.indices.contains(index) ? list[index] : nil
    }
}
