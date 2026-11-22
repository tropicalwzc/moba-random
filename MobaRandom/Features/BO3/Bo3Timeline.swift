import SwiftUI

struct Bo3Timeline: View {
    let sequence: [Bo3Step]
    let actions: [Bo3Action]
    let currentIndex: Int?
    let gameNumber: Int
    let noBan: Bool
    let compact: Bool
    var strip: Bool = false

    private var hint: String {
        if let currentIndex {
            return "第 \(gameNumber) 局 · 第 \(currentIndex + 1) / \(sequence.count) 手"
        }
        if gameNumber > 0, actions.count >= sequence.count {
            return "第 \(gameNumber) 局 · \(sequence.count) / \(sequence.count) 已完成"
        }
        if gameNumber > 0 {
            return "第 \(gameNumber) 局 · \(sequence.count) 手"
        }
        return sequence.count == 8 ? "第 1、2 局 12 手 · 第 3 局 8 手" : "第 1 局 A 先手 · 第 2 局 B 先手"
    }

    var body: some View {
        if strip {
            stripContent
        } else {
            Bo3Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("征召顺序")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(hint)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    if compact {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6),
                            spacing: 4
                        ) {
                            ForEach(Array(sequence.enumerated()), id: \.offset) { index, step in
                                chip(index: index, step: step)
                            }
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(Array(sequence.enumerated()), id: \.offset) { index, step in
                                    if shouldShowBreak(before: index) {
                                        Rectangle()
                                            .fill(Color.secondary.opacity(0.18))
                                            .frame(width: 1, height: 32)
                                            .padding(.horizontal, 1)
                                    }
                                    chip(index: index, step: step)
                                        .frame(width: 58)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var stripContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(sequence.enumerated()), id: \.offset) { index, step in
                    if shouldShowBreak(before: index) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.18))
                            .frame(width: 1, height: 28)
                    }
                    chip(index: index, step: step)
                        .frame(width: 52)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func shouldShowBreak(before index: Int) -> Bool {
        if noBan { return index == 4 }
        return index == 2 || index == 6 || index == 8
    }

    private func chip(index: Int, step: Bo3Step) -> some View {
        let action = actions.indices.contains(index) ? actions[index] : nil
        let isCurrent = index == currentIndex
        let teamColor = Bo3Palette.teamColor(step.team)
        let teamInk = Bo3Palette.teamInkColor(step.team)
        let isComplete = action != nil

        return VStack(spacing: 3) {
            HStack(spacing: 2) {
                Text(index + 1 < 10 ? "0\(index + 1)" : "\(index + 1)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("\(step.team.shortLabel)\(step.type.shortLabel)")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(teamInk)
            }

            Text(action?.hero ?? (isCurrent ? "选择中" : "—"))
                .font(.system(size: 9, weight: isCurrent ? .bold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(
            chipBackground(isCurrent: isCurrent, isComplete: isComplete, teamColor: teamColor),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(
                    isCurrent ? Bo3Palette.gold.color : teamColor.opacity(isComplete ? 0.25 : 0.08),
                    lineWidth: isCurrent ? 1.5 : 1
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(index: index, step: step, action: action, isCurrent: isCurrent))
    }

    private func chipBackground(isCurrent: Bool, isComplete: Bool, teamColor: Color) -> Color {
        if isCurrent {
            return Bo3Palette.gold.color.opacity(0.14)
        }
        if isComplete {
            return teamColor.opacity(0.1)
        }
        return Color(uiColor: .tertiarySystemFill)
    }

    private func accessibilityLabel(
        index: Int,
        step: Bo3Step,
        action: Bo3Action?,
        isCurrent: Bool
    ) -> String {
        let prefix = "第 \(index + 1) 手，\(step.team.sideLabel)\(step.type.label)"
        if let action {
            return "\(prefix)，已完成：\(action.hero)"
        }
        return isCurrent ? "\(prefix)，进行中" : "\(prefix)，尚未进行"
    }
}
