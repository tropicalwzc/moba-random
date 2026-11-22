import SwiftUI

struct Bo3ArenaHeader: View {
    let series: Bo3Series
    let sequence: [Bo3Step]
    let currentStep: (step: Bo3Step, index: Int)?
    let pool: Bo3Pool
    let reduceMotion: Bool
    var compact: Bool = false

    let onStart: () -> Void
    let onNext: () -> Void
    let onWinner: (Bo3Team) -> Void
    let onReopenWinner: () -> Void
    let onReset: () -> Void
    let onEditPool: () -> Void

    private var wins: (a: Int, b: Int) { series.wins }
    private var activeGame: Bo3Game? { series.activeGame }
    private var actions: [Bo3Action] { activeGame?.actions ?? [] }
    private var draftComplete: Bool {
        guard let activeGame, activeGame.started else { return false }
        return actions.count >= sequence.count
    }
    private var pendingWinner: Bool {
        draftComplete && activeGame?.winner == nil
    }
    private var canStartNext: Bool {
        Bo3DraftEngine.canStartNextGame(in: series, pool: pool)
    }
    private var nextRequirement: Int {
        Bo3DraftEngine.nextGameRequirement(in: series)
    }
    private var remainingPicks: Int {
        Bo3DraftEngine.remainingPicksAvailable(in: series, pool: pool)
    }

    private var noBan: Bool {
        guard series.currentGame == 3 else { return false }
        if let game = series.activeGame, game.started {
            return game.noBan
        }
        return series.noBanGame3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 14) {
            scoreRow
            if !compact {
                Rectangle()
                    .fill(Bo3Palette.gold.color.opacity(0.2))
                    .frame(height: 1)
            }
            statusSection
        }
        .padding(compact ? 10 : 16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous)
                .stroke(Bo3Palette.gold.color.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 12, y: 3)
        .overlay(alignment: .topTrailing) {
            if compact {
                gameBadge.offset(x: 8, y: -8)
            }
        }
    }

    private var gameBadge: some View {
        Text(series.currentGame > 0 ? "第 \(series.currentGame) 局" : "BO3")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Bo3Palette.goldInk.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule().stroke(Bo3Palette.gold.color.opacity(0.3), lineWidth: 1)
            }
            .accessibilityLabel(series.currentGame > 0 ? "第 \(series.currentGame) 局" : "BO3")
    }

    // MARK: - Score

    private var scoreRow: some View {
        let aSeats = series.seats?.a.map(String.init).joined(separator: "，") ?? "待抽签"
        let bSeats = series.seats?.b.map(String.init).joined(separator: "，") ?? "待抽签"

        return HStack(alignment: .center, spacing: compact ? 6 : 10) {
            teamSide(.a)

            VStack(spacing: compact ? 3 : 5) {
                HStack(spacing: 14) {
                    Bo3SeatNumbers(seats: series.seats?.a, team: .a)
                    Bo3SeatNumbers(seats: series.seats?.b, team: .b)
                }
                .accessibilityHidden(true)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(wins.a)")
                        .foregroundStyle(Bo3Palette.teamInkColor(.a))
                    Text(":")
                        .foregroundStyle(.secondary)
                    Text("\(wins.b)")
                        .foregroundStyle(Bo3Palette.teamInkColor(.b))
                }
                .font(.system(size: compact ? 24 : 28, weight: .heavy, design: .rounded))
                .contentTransition(reduceMotion ? .identity : .numericText())

                if !compact {
                    Text(series.currentGame == 0 ? "BO3 · 全局 BP" : "第 \(series.currentGame) 局")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            teamSide(.b)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(series.teamNames.a) \(wins.a) 比 \(wins.b) \(series.teamNames.b)，\(series.currentGame == 0 ? "尚未开始" : "第 \(series.currentGame) 局")，红方座位 \(aSeats)，紫方座位 \(bSeats)"
        )
    }

    private func teamSide(_ team: Bo3Team) -> some View {
        let ink = Bo3Palette.teamInkColor(team)
        let winsForTeam = team == .a ? wins.a : wins.b

        return VStack(alignment: team == .a ? .leading : .trailing, spacing: compact ? 3 : 5) {
            Text(team.sideLabel)
                .font(.system(size: compact ? 8 : 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 6) {
                if team == .a {
                    Bo3WinPips(wins: winsForTeam, team: team)
                }
                Text(series.teamNames.name(for: team))
                    .font(.system(size: compact ? 14 : 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if team == .b {
                    Bo3WinPips(wins: winsForTeam, team: team)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: team == .a ? .leading : .trailing)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusSection: some View {
        if series.isSeriesOver, let champion = series.champion {
            championState(champion)
        } else if pendingWinner {
            winnerPrompt
        } else if let activeGame, draftComplete, let winner = activeGame.winner {
            gameCompleteState(winner)
        } else if let currentStep {
            currentTurnState(currentStep.step, index: currentStep.index)
        } else {
            startState
        }
    }

    private var startState: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 9) {
            if !compact {
                Text("准备开始")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Bo3Palette.goldInk.color)
            }

            if !compact {
                Text("BO3 · 全局 BP")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            }

            if !compact {
                Text(
                    series.noBanGame3
                        ? "第 1、2 局 12 手 · 第 3 局无 BAN 仅 8 手 · 前序选用角色全局锁定"
                        : "每局 12 手 · 双方各 2 禁 4 选 · 前序选用角色全局锁定"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if pool.total < Bo3DraftEngine.minimumPoolForGame {
                shortageBanner(
                    "角色池 \(pool.total) 人，至少需要 \(Bo3DraftEngine.minimumPoolForGame) 人才能开始。",
                    actionTitle: "编辑角色池",
                    action: onEditPool
                )
            }

            primaryButton("开始第 1 局", enabled: pool.total >= Bo3DraftEngine.minimumPoolForGame, action: onStart)
        }
    }

    private func currentTurnState(_ step: Bo3Step, index: Int) -> some View {
        let teamInk = Bo3Palette.teamInkColor(step.team)
        let done = actions.filter { $0.team == step.team && $0.type == step.type }.count
        let cap = step.type == .ban ? 2 : 4

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: compact ? 8 : 11) {
                Bo3TeamBadge(team: step.team, size: compact ? 30 : 38)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        compact
                            ? "第 \(index + 1) / \(sequence.count) 手"
                            : "第 \(series.currentGame) 局 · 第 \(index + 1) / \(sequence.count) 手"
                    )
                        .font(.system(size: compact ? 9 : 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)

                    Text("\(series.teamNames.name(for: step.team)) \(step.type.label)")
                        .font(compact ? .subheadline.bold() : .title3.bold())
                        .foregroundStyle(.primary)

                    if !compact {
                        Text("点击下方角色完成 \(step.type.shortLabel) · 分类仅为推荐位置")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 4)

                VStack(spacing: 2) {
                    Text(step.type == .ban ? "BAN" : "PICK")
                        .font(.system(size: compact ? 8 : 9, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(teamInk)
                    Text("\(done + 1) / \(cap)")
                        .font(.system(size: compact ? 12 : 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "第 \(series.currentGame) 局，第 \(index + 1) 手，共 \(sequence.count) 手，\(series.teamNames.name(for: step.team)) \(step.type.label)"
            )

            if compact {
                Bo3Timeline(
                    sequence: sequence,
                    actions: actions,
                    currentIndex: index,
                    gameNumber: series.currentGame,
                    noBan: noBan,
                    compact: true,
                    strip: true
                )
            }
        }
    }

    private var winnerPrompt: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 9) {
            if !compact {
                Text("第 \(series.currentGame) 局 · 征召完成")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Bo3Palette.goldInk.color)
            }
            Text("请判定本局胜者")
                .font(compact ? .subheadline.bold() : .title3.bold())
                .foregroundStyle(.primary)
            if !compact {
                Text("比分自动累计，先胜 2 局者赢得 BO3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                winnerButton(.a)
                winnerButton(.b)
            }
        }
    }

    private func gameCompleteState(_ winner: Bo3Team) -> some View {
        let nextGame = min(3, series.currentGame + 1)
        let nextNoBan = nextGame == 3 && series.noBanGame3

        return VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            if !compact {
                Text("第 \(series.currentGame) 局 · 已结束")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }

            Text("\(series.teamNames.name(for: winner)) 拿下本局")
                .font(compact ? .subheadline.bold() : .title3.bold())
                .foregroundStyle(Bo3Palette.teamInkColor(winner))

            if !compact {
                Text("当前比分 \(wins.a) : \(wins.b) · 下一局\(nextNoBan ? "无 BAN，仅 8 手" : "继续 12 手征召")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if canStartNext {
                primaryButton("进入第 \(nextGame) 局 →", enabled: true, action: onNext)
            } else {
                shortageBanner(
                    "剩余可选角色 \(remainingPicks) 名，不足以下一局的 \(nextRequirement) 手征召。请扩充角色池。",
                    actionTitle: "编辑角色池",
                    action: onEditPool
                )
            }
        }
    }

    private func championState(_ champion: Bo3Team) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            if !compact {
                Text("BO3 · 系列赛结束")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Bo3Palette.goldInk.color)
            }

            Text("\(series.teamNames.name(for: champion)) 夺得系列赛胜利")
                .font(compact ? .subheadline.bold() : .title3.bold())
                .foregroundStyle(.primary)

            if !compact {
                Text("最终比分 \(wins.a) : \(wins.b)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                secondaryButton("重新判定本局胜者", action: onReopenWinner)
                secondaryButton("新系列赛", action: onReset)
            }
        }
    }

    private func winnerButton(_ team: Bo3Team) -> some View {
        let color = Bo3Palette.teamColor(team)
        let ink = Bo3Palette.teamInkColor(team)
        return Button {
            onWinner(team)
        } label: {
            Text("\(series.teamNames.name(for: team)) 获胜")
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 8 : 10)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 9 : 11)
                .background(Color.accentColor, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 8 : 9)
                .background(
                    Color(uiColor: .tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func shortageBanner(
        _ message: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(actionTitle, action: action)
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
                .buttonStyle(.plain)
        }
        .padding(9)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        }
    }
}
