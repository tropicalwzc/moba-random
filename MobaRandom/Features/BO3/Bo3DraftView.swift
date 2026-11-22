import SwiftUI

struct Bo3DraftView: View {
    @AppStorage("moba_role_pool") private var poolText = GroupingEngine.defaultPoolText

    @State private var store = Bo3SeriesStore()
    @State private var selectedRole = "all"
    @State private var searchText = ""
    @State private var onlyAvailable = false
    @State private var showsSearch = false
    @State private var presentedSheet: Bo3Sheet?
    @State private var toast: Bo3Toast?
    @State private var toastToken = UUID()
    @State private var isShowingResetConfirmation = false
    @State private var boardSize = CGSize(width: 800, height: 800)

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Bo3Sheet: String, Identifiable {
        case settings
        case rules
        case history

        var id: String { rawValue }
    }

    private var pool: Bo3Pool {
        Bo3Pool(text: poolText)
    }

    private var series: Bo3Series {
        store.series
    }

    private var sequence: [Bo3Step] {
        series.currentGame == 0
            ? Bo3DraftEngine.stepSequence
            : Bo3DraftEngine.activeSequence(in: series)
    }

    private var currentStep: (step: Bo3Step, index: Int)? {
        Bo3DraftEngine.currentStep(in: series)
    }

    private var activeGame: Bo3Game? {
        series.activeGame
    }

    private var noBan: Bool {
        guard series.currentGame == 3 else { return false }
        if let activeGame, activeGame.started {
            return activeGame.noBan
        }
        return series.noBanGame3
    }

    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    /// The keyboard reduces the reported height on iPhone. Keep the tallest
    /// height for the current width so showing the search field cannot flip the
    /// board into the short-height fallback and tear down the focused field.
    private func updateBoardSize(_ newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        if newSize.width != boardSize.width || newSize.height > boardSize.height {
            boardSize = newSize
        }
    }

    private func usesThreeColumns() -> Bool {
        horizontalSizeClass == .regular && boardSize.width >= 900
    }

    private func usesTwoColumns() -> Bool {
        !isAccessibilitySize
            && !usesThreeColumns()
            && (horizontalSizeClass == .regular || verticalSizeClass == .compact)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isAccessibilitySize || boardSize.height < 620 {
                    accessibilityBoard
                } else if usesThreeColumns() {
                    regularLandscapeBoard
                } else if usesTwoColumns() {
                    twoColumnBoard
                } else {
                    compactBoard
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                updateBoardSize(newSize)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("全局 BP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        presentedSheet = .rules
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("比赛规则")
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button(action: undo) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!store.canUndo)
                    .accessibilityLabel("撤销本局上一步")
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingResetConfirmation = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(store.hasProgress ? Color.red : Color.secondary)
                    }
                    .disabled(!store.hasProgress)
                    .accessibilityLabel("全局重置")
                }

                if series.currentGame > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            presentedSheet = .history
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .accessibilityLabel("系列赛记录")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentedSheet = .settings
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("BO3 设置")
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .settings:
                    Bo3SettingsView(
                        series: series,
                        poolText: $poolText,
                        onApply: applySettings
                    )
                case .rules:
                    Bo3RulesView()
                case .history:
                    Bo3HistoryView(series: series)
                }
            }
            .confirmationDialog(
                "清空全部对局？",
                isPresented: $isShowingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("全局重置", role: .destructive) {
                    store.reset()
                    showToast("已清空全部对局，角色池与设置已保留", .success)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("比分、三局征召记录和当前进度都会被清除；角色池、队伍名称与赛制设置会保留。")
            }
            .overlay(alignment: .top) {
                if let toast {
                    Bo3ToastView(toast: toast)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    store.save()
                }
            }
        }
    }

    // MARK: - Layouts

    private var compactBoard: some View {
        VStack(spacing: 8) {
            arenaHeader(compact: true)
            Bo3LineupStrip(series: series, compact: true, noBan: noBan)
            poolHeader
            ScrollView(.vertical, showsIndicators: false) {
                heroGrid
                    .padding(.bottom, 84)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private var twoColumnBoard: some View {
        let compactHeader = verticalSizeClass == .compact

        return HStack(alignment: .top, spacing: 12) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: compactHeader ? 8 : 10) {
                    arenaHeader(compact: compactHeader)
                    if !compactHeader {
                        timeline(compact: true)
                    }
                    Bo3LineupStrip(series: series, compact: true, noBan: noBan)
                    poolHeader
                }
                .padding(.bottom, 16)
            }
            .frame(width: 330)

            ScrollView(.vertical, showsIndicators: false) {
                heroGrid
                    .padding(.bottom, 84)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private var regularLandscapeBoard: some View {
        HStack(alignment: .top, spacing: 12) {
            Bo3TeamPanel(
                series: series,
                team: .a,
                isActive: currentStep?.step.team == .a
            )
            .frame(width: 260)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    arenaHeader()
                    timeline(compact: false)
                    poolHeader
                    heroGrid
                        .padding(.bottom, 24)
                }
            }

            Bo3TeamPanel(
                series: series,
                team: .b,
                isActive: currentStep?.step.team == .b
            )
            .frame(width: 260)
        }
        .padding(14)
    }

    private var accessibilityBoard: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                arenaHeader()
                timeline(compact: true)
                Bo3LineupStrip(series: series, compact: false, noBan: noBan)
                poolHeader
                heroGrid
                    .padding(.bottom, 88)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
        }
    }

    // MARK: - Sections

    private func arenaHeader(compact: Bool = false) -> some View {
        Bo3ArenaHeader(
            series: series,
            sequence: sequence,
            currentStep: currentStep,
            pool: pool,
            reduceMotion: reduceMotion,
            compact: compact,
            onStart: startGame,
            onNext: startGame,
            onWinner: setWinner,
            onReopenWinner: reopenWinner,
            onReset: { isShowingResetConfirmation = true },
            onEditPool: { presentedSheet = .settings }
        )
    }

    private func timeline(compact: Bool) -> some View {
        Bo3Timeline(
            sequence: sequence,
            actions: activeGame?.actions ?? [],
            currentIndex: currentStep?.index,
            gameNumber: series.currentGame,
            noBan: noBan,
            compact: compact
        )
    }

    private var poolHeader: some View {
        Bo3PoolHeader(
            pool: pool,
            series: series,
            selectedRole: $selectedRole,
            searchText: $searchText,
            onlyAvailable: $onlyAvailable,
            showsSearch: $showsSearch,
            onClearFilters: clearFilters
        )
    }

    private var heroGrid: some View {
        Bo3HeroGrid(
            pool: pool,
            series: series,
            selectedRole: selectedRole,
            searchText: searchText,
            onlyAvailable: onlyAvailable,
            onSelect: selectHero,
            onClearFilters: clearFilters
        )
    }

    // MARK: - Actions

    private func startGame() {
        let previousGame = series.currentGame
        do {
            try store.startGame(pool: pool)
            Bo3Haptics.success()
            if previousGame == 0 {
                let seats = store.series.seats
                let a = seats?.a.map(String.init).joined(separator: "·") ?? ""
                let b = seats?.b.map(String.init).joined(separator: "·") ?? ""
                showToast("第 1 局开始 · 红方 \(a) / 紫方 \(b)", .success)
            } else {
                let game = store.series.games[store.series.currentGame - 1]
                showToast(
                    "第 \(store.series.currentGame) 局开始" + (game.noBan ? " · 本局无 BAN，8 手选用" : ""),
                    .success
                )
            }
            clearFilters()
        } catch {
            Bo3Haptics.warning()
            showToast(error.localizedDescription, .warning)
        }
    }

    private func setWinner(_ team: Bo3Team) {
        do {
            try store.setWinner(team)
            Bo3Haptics.success()
            let wins = store.series.wins
            if let champion = store.series.champion {
                showToast(
                    "\(store.series.teamNames.name(for: champion)) 赢得 BO3 · 比分 \(wins.a) : \(wins.b)",
                    .success
                )
            } else {
                showToast(
                    "\(store.series.teamNames.name(for: team)) 拿下第 \(store.series.currentGame) 局 · 比分 \(wins.a) : \(wins.b)",
                    .success
                )
            }
        } catch {
            Bo3Haptics.warning()
            showToast(error.localizedDescription, .warning)
        }
    }

    private func reopenWinner() {
        if store.reopenWinner() {
            showToast("已清除本局胜者判定，请重新选择", .info)
        } else {
            showToast("没有可重新判定的胜者", .warning)
        }
    }

    private func undo() {
        if store.undo() {
            Bo3Haptics.tap()
            showToast("已撤销本局上一步", .info)
        } else {
            showToast("本局还没有可撤销的操作", .warning)
        }
    }

    private func selectHero(_ hero: String) {
        guard series.currentGame > 0 else {
            Bo3Haptics.warning()
            showToast("请先点击「开始第 1 局」", .warning)
            return
        }

        guard Bo3DraftEngine.currentStep(in: series) != nil else {
            Bo3Haptics.warning()
            if activeGame?.winner != nil {
                showToast("第 \(series.currentGame) 局已结束，请进入下一局或重新判定胜者", .warning)
            } else if activeGame?.started == true {
                showToast("本局征召已完成，请判定胜者", .warning)
            } else {
                showToast("请先开始一局比赛", .warning)
            }
            return
        }

        let availability = Bo3DraftEngine.availability(of: hero, in: series)
        guard availability.isAvailable else {
            Bo3Haptics.warning()
            showToast(Bo3DraftEngine.lockMessage(for: availability, in: series), .warning)
            return
        }

        let role = pool.role(for: hero) ?? "未知"
        do {
            try store.choose(hero: hero, role: role)
            Bo3Haptics.tap()
            if let next = Bo3DraftEngine.currentStep(in: store.series) {
                let name = store.series.teamNames.name(for: next.step.team)
                showToast(
                    "已记录 \(hero) · 轮到 \(name) \(next.step.type.label)",
                    .info
                )
            } else {
                showToast("第 \(series.currentGame) 局征召完成 · 请判定胜者", .success)
            }
        } catch {
            Bo3Haptics.warning()
            showToast(error.localizedDescription, .warning)
        }
    }

    private func clearFilters() {
        selectedRole = "all"
        searchText = ""
        onlyAvailable = false
        showsSearch = false
    }

    private func applySettings(names: Bo3TeamNames, noBanGame3: Bool, newPoolText: String) {
        store.updateTeamNames(names)
        store.updateNoBanGame3(noBanGame3)
        poolText = newPoolText
        showToast("设置已更新", .success)
    }

    private func showToast(_ message: String, _ tone: Bo3ToastTone) {
        let token = UUID()
        toastToken = token
        withAnimation(
            reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.3, dampingFraction: 0.86)
        ) {
            toast = Bo3Toast(message: message, tone: tone)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            guard toastToken == token else { return }
            withAnimation(
                reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.2)
            ) {
                toast = nil
            }
        }
    }
}

#Preview {
    Bo3DraftView()
}
