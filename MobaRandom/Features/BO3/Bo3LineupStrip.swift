import SwiftUI

struct Bo3LineupStrip: View {
    let series: Bo3Series
    var compact: Bool = true
    var noBan: Bool = false

    private var gameActions: [Bo3Action] {
        series.activeGame?.actions ?? []
    }

    var body: some View {
        Bo3Card {
            VStack(spacing: 8) {
                row(.a)
                row(.b)
            }
        }
    }

    private func row(_ team: Bo3Team) -> some View {
        let actions = gameActions.filter { $0.team == team }
        let bans = actions.filter { $0.type == .ban }
        let picks = actions.filter { $0.type == .pick }
        let color = Bo3Palette.teamColor(team)

        return HStack(spacing: compact ? 4 : 6) {
            HStack(spacing: 5) {
                Bo3TeamBadge(team: team, size: 22)
                Text(series.teamNames.name(for: team))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(width: compact ? 68 : 120, alignment: .leading)

            if noBan {
                Text("NO BAN")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(
                        Color(uiColor: .tertiarySystemFill),
                        in: Capsule()
                    )
            } else {
                ForEach(0..<2, id: \.self) { index in
                    slot(
                        action: value(in: bans, at: index),
                        kind: .ban,
                        team: team,
                        color: color
                    )
                }

                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: 1, height: 22)
                    .padding(.horizontal, 1)
            }

            ForEach(0..<4, id: \.self) { index in
                slot(
                    action: value(in: picks, at: index),
                    kind: .pick,
                    team: team,
                    color: color
                )
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            noBan
                ? "\(series.teamNames.name(for: team))，本局无禁用，选用 \(picks.map(\.hero).joined(separator: "、"))"
                : "\(series.teamNames.name(for: team))，禁用 \(bans.map(\.hero).joined(separator: "、"))，选用 \(picks.map(\.hero).joined(separator: "、"))"
        )
    }

    @ViewBuilder
    private func slot(
        action: Bo3Action?,
        kind: Bo3ActionType,
        team: Bo3Team,
        color: Color
    ) -> some View {
        if let action {
            ZStack(alignment: .topLeading) {
                Bo3AvatarView(name: action.hero, size: kind == .ban ? 26 : 30)
                if kind == .ban {
                    Rectangle()
                        .fill(color)
                        .frame(height: 1.5)
                        .rotationEffect(.degrees(-45))
                        .frame(width: 34)
                        .offset(x: -2, y: 13)
                }
            }
            .frame(width: kind == .ban ? 26 : 30, height: 30)
            .accessibilityLabel("\(team.sideLabel)\(kind.label) \(action.hero)")
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
                .frame(width: kind == .ban ? 26 : 30, height: kind == .ban ? 26 : 30)
                .overlay {
                    Text(kind.shortLabel)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .frame(height: 30)
                .accessibilityLabel("\(team.sideLabel)\(kind.label)位，待定")
        }
    }

    private func value(in list: [Bo3Action], at index: Int) -> Bo3Action? {
        list.indices.contains(index) ? list[index] : nil
    }
}
