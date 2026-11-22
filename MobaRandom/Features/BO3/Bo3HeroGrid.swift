import SwiftUI

struct Bo3PoolHeader: View {
    let pool: Bo3Pool
    let series: Bo3Series
    @Binding var selectedRole: String
    @Binding var searchText: String
    @Binding var onlyAvailable: Bool
    @Binding var showsSearch: Bool
    let onClearFilters: () -> Void

    private var currentGameCount: Int {
        Bo3DraftEngine.currentGameHeroes(in: series).count
    }

    private var priorLockedCount: Int {
        Bo3DraftEngine.pickedHeroes(
            in: series,
            throughGameNumber: max(0, series.currentGame - 1)
        ).count
    }

    private var availableCount: Int {
        pool.allHeroes.filter {
            Bo3DraftEngine.availability(of: $0, in: series).isAvailable
        }.count
    }

    private var hasFilters: Bool {
        selectedRole != "all" || !searchText.isEmpty || onlyAvailable
    }

    var body: some View {
        Bo3Card {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            chip(
                                title: "全部",
                                count: pool.total,
                                color: .secondary,
                                selected: selectedRole == "all"
                            ) {
                                selectedRole = "all"
                            }

                            ForEach(pool.categories, id: \.name) { category in
                                chip(
                                    title: category.name,
                                    count: category.heroes.count,
                                    color: Bo3Palette.roleColor(for: category.name),
                                    selected: selectedRole == category.name
                                ) {
                                    selectedRole = category.name
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }

                    iconButton(
                        systemName: onlyAvailable
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle",
                        active: onlyAvailable,
                        label: onlyAvailable ? "仅看可用：已开启" : "仅看可用：已关闭"
                    ) {
                        onlyAvailable.toggle()
                        Bo3Haptics.tap()
                    }

                    iconButton(
                        systemName: showsSearch ? "xmark.circle.fill" : "magnifyingglass",
                        active: showsSearch,
                        label: showsSearch ? "关闭搜索" : "搜索角色"
                    ) {
                        showsSearch.toggle()
                        if !showsSearch {
                            searchText = ""
                        }
                    }
                }

                if showsSearch {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("搜索角色", text: $searchText)
                            .font(.subheadline)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Color(uiColor: .tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                }

                HStack(spacing: 10) {
                    stat("本局已用", value: currentGameCount)
                    stat("前序锁定", value: priorLockedCount)
                    stat("当前可选", value: availableCount)
                    Spacer(minLength: 0)
                    if hasFilters {
                        Button("清除") {
                            onClearFilters()
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func chip(
        title: String,
        count: Int,
        color: Color,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.caption.weight(selected ? .bold : .medium))
                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                selected
                    ? Color(uiColor: .tertiarySystemFill)
                    : Color(uiColor: .quaternarySystemFill),
                in: Capsule()
            )
            .overlay {
                if selected {
                    Capsule().stroke(Bo3Palette.gold.color.opacity(0.4), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(count) 个角色")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func iconButton(
        systemName: String,
        active: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(active ? Bo3Palette.gold.color : Color.secondary)
                .frame(width: 32, height: 32)
                .background(
                    Color(uiColor: .tertiarySystemFill),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func stat(_ title: String, value: Int) -> some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}

struct Bo3HeroGrid: View {
    let pool: Bo3Pool
    let series: Bo3Series
    let selectedRole: String
    let searchText: String
    let onlyAvailable: Bool
    let onSelect: (String) -> Void
    let onClearFilters: () -> Void

    private struct HeroItem: Identifiable {
        let hero: String
        let role: String
        var id: String { hero }
    }

    private var availability: [String: Bo3Availability] {
        Bo3DraftEngine.availabilityMap(for: pool.allHeroes, in: series)
    }

    private func items(using map: [String: Bo3Availability]) -> [HeroItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result: [HeroItem] = []

        for category in pool.categories {
            guard selectedRole == "all" || selectedRole == category.name else { continue }
            for hero in category.heroes {
                if !query.isEmpty, !hero.lowercased().contains(query) {
                    continue
                }
                if onlyAvailable, map[hero]?.isAvailable != true {
                    continue
                }
                result.append(HeroItem(hero: hero, role: category.name))
            }
        }
        return result
    }

    var body: some View {
        let map = availability
        let filtered = items(using: map)

        return Group {
            if filtered.isEmpty {
                emptyState
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 62, maximum: 82), spacing: 8)],
                    spacing: 10
                ) {
                    ForEach(filtered) { item in
                        Bo3HeroCard(
                            hero: item.hero,
                            role: item.role,
                            availability: map[item.hero] ?? .available,
                            series: series,
                            onSelect: { onSelect(item.hero) }
                        )
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text("没有符合条件的角色")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Button("清除筛选") {
                onClearFilters()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

private struct Bo3HeroCard: View {
    let hero: String
    let role: String
    let availability: Bo3Availability
    let series: Bo3Series
    let onSelect: () -> Void

    private var isUsed: Bool {
        !availability.isAvailable
    }

    private var badgeText: String {
        switch availability {
        case .available:
            return ""
        case let .currentGame(action):
            return "\(action.team.shortLabel)\(action.type.shortLabel)"
        case let .globalPick(game, _):
            return "G\(game)锁"
        }
    }

    private var badgeColor: Color {
        switch availability {
        case .available:
            return .clear
        case let .currentGame(action):
            return Bo3Palette.teamInkColor(action.team)
        case .globalPick:
            return Bo3Palette.gold.color
        }
    }

    private var badgeTextColor: Color {
        if case .globalPick = availability { return .black }
        return .white
    }

    private var lockMessage: String {
        Bo3DraftEngine.lockMessage(for: availability, in: series)
    }

    private var roleColor: Color {
        Bo3Palette.roleColor(for: role)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 5) {
                Bo3AvatarView(name: hero, size: 50, isUsed: isUsed)
                    .overlay(alignment: .topLeading) {
                        if !badgeText.isEmpty {
                            Text(badgeText)
                                .font(.system(size: 7, weight: .heavy))
                                .foregroundStyle(badgeTextColor)
                                .lineLimit(1)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1.5)
                                .background(badgeColor, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                                .padding(3)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        Text(role)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(roleColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1.5)
                            .background(Color.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .padding(3)
                    }

                Text(hero)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isUsed ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 4)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isUsed ? Color.secondary.opacity(0.22) : Color.clear,
                        style: StrokeStyle(lineWidth: 1, dash: isUsed ? [3, 3] : [])
                    )
            }
            .opacity(isUsed ? 0.64 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isUsed ? lockMessage : "点按记录当前征召步骤")
    }

    private var accessibilityLabel: String {
        var label = "\(hero)，推荐位置 \(role)"
        if isUsed {
            label += "，\(lockMessage)"
        } else {
            label += "，可选"
        }
        return label
    }
}
