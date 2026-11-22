import SwiftUI
import UIKit

enum Bo3ToastTone: Equatable {
    case success
    case warning
    case info

    var color: Color {
        switch self {
        case .success: Color.green
        case .warning: Color.orange
        case .info: Color.blue
        }
    }

    var icon: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }
}

struct Bo3Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let tone: Bo3ToastTone
}

struct Bo3ToastView: View {
    let toast: Bo3Toast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.tone.icon)
                .foregroundStyle(toast.tone.color)
            Text(toast.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(toast.tone.color.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .combine)
    }
}

struct Bo3TeamBadge: View {
    let team: Bo3Team
    var size: CGFloat = 34

    var body: some View {
        Text(team.shortLabel)
            .font(.system(size: size * 0.44, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Bo3Palette.teamInkColor(team), in: Circle())
            .accessibilityHidden(true)
    }
}

struct Bo3WinPips: View {
    let wins: Int
    let team: Bo3Team

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(index < wins ? Bo3Palette.teamColor(team) : Color.secondary.opacity(0.25))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityLabel("BO3 胜场 \(wins) / 2")
    }
}

struct Bo3SeatNumbers: View {
    let seats: [Int]?
    let team: Bo3Team

    var body: some View {
        if let seats, seats.count == 4 {
            HStack(spacing: 3) {
                ForEach(seats, id: \.self) { seat in
                    Text("\(seat)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Bo3Palette.teamInkColor(team))
                        .frame(width: 24, height: 24)
                        .background(
                            Bo3Palette.teamColor(team).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Bo3Palette.teamColor(team).opacity(0.28), lineWidth: 1)
                        }
                }
            }
            .accessibilityLabel("座位 \(seats.map(String.init).joined(separator: "，"))")
        } else {
            Text("待抽签")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(height: 24)
        }
    }
}

struct Bo3Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

@MainActor
enum Bo3Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
