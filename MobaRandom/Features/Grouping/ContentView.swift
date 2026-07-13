import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage("moba_role_pool") private var rolePoolText = GroupingEngine.defaultPoolText

    @State private var lastGameText = ""
    @State private var allowDuplicate = false
    @State private var result: GroupingResult?
    @State private var presentedError: PresentedError?
    @State private var isShowingResetConfirmation = false
    @State private var copied = false
    @State private var hasGeneratedInitialResult = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        rolePoolSection
                        rulesSection

                        if let result {
                            resultSection(result)
                                .id("result")
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: 760)
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Color(uiColor: .systemGroupedBackground))
                .onAppear {
                    guard !hasGeneratedInitialResult else { return }
                    hasGeneratedInitialResult = true
                    if rolePoolText.isEmpty {
                        rolePoolText = GroupingEngine.defaultPoolText
                    }
                    generate()
                }
                .onChange(of: result) {
                    guard result != nil else { return }
                    withAnimation(.easeOut(duration: 0.35)) {
                        proxy.scrollTo("result", anchor: .bottom)
                    }
                }
            }
            .navigationTitle("分组助手")
            .navigationBarTitleDisplayMode(.inline)
        }
        .confirmationDialog(
            "恢复默认角色池？",
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("恢复默认", role: .destructive) {
                rolePoolText = GroupingEngine.defaultPoolText
                generate()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("当前的自定义设置将会丢失。")
        }
        .alert(item: $presentedError) { error in
            Alert(
                title: Text("无法生成分组"),
                message: Text(error.message),
                dismissButton: .default(Text("好"))
            )
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.blue.gradient)
                .accessibilityHidden(true)

            Text("MOBA 分组助手 Pro")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("动态角色池 · 智能避让上一局 · 毫秒级随机")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 4)
    }

    private var rolePoolSection: some View {
        AppSection {
            HStack {
                Label("角色池设置", systemImage: "person.3.sequence.fill")
                    .font(.headline)
                Spacer()
                Button("恢复默认") {
                    isShowingResetConfirmation = true
                }
                .font(.subheadline)
            }

            TextEditor(text: $rolePoolText)
                .font(.body.monospaced())
                .frame(minHeight: 170)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                }
                .accessibilityLabel("角色池")

            HintText("支持自定义职业名称；角色之间可用顿号、逗号或空格分隔。修改会自动保存。")
        }
    }

    private var rulesSection: some View {
        AppSection {
            Label("分组规则", systemImage: "slider.horizontal.3")
                .font(.headline)

            Toggle(isOn: $allowDuplicate) {
                HStack(spacing: 8) {
                    Text("允许两组使用相同角色")
                    if allowDuplicate {
                        Text("镜像模式")
                            .font(.caption2.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.orange, in: Capsule())
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: allowDuplicate)

            HintText("开启后，A/B 两组会独立抽取，各分路可能使用同一个角色。")

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("上一局使用过的角色（选填）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if lastGameText.isEmpty {
                        Text("例如：温迪，胡桃，钟离，行秋")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $lastGameText)
                        .frame(minHeight: 84)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                        }
                }
            }

            HintText("填入上一局角色后，本次抽中它们的权重会降至其他角色的 1/10。")

            Button {
                generate()
            } label: {
                Label("开始随机分组", systemImage: "dice.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func resultSection(_ result: GroupingResult) -> some View {
        AppSection {
            HStack(alignment: .firstTextBaseline) {
                Label("分组结果", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
                Text("种子：\(result.seed)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            TeamResultView(
                title: "Group A",
                color: .blue,
                players: result.playersA,
                roles: result.rolesA
            )

            TeamResultView(
                title: "Group B",
                color: .orange,
                players: result.playersB,
                roles: result.rolesB
            )

            Button {
                UIPasteboard.general.string = result.formattedText
                copied = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    copied = false
                }
            } label: {
                Label(copied ? "已复制到剪贴板" : "复制分组结果", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .foregroundStyle(copied ? .green : .blue)
        }
    }

    private func generate() {
        do {
            let newResult = try GroupingEngine.generate(
                poolText: rolePoolText,
                lastGameText: lastGameText,
                allowDuplicate: allowDuplicate
            )
            withAnimation(.easeOut(duration: 0.25)) {
                result = newResult
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            presentedError = PresentedError(message: message)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

private struct AppSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
    }
}

private struct HintText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label(text, systemImage: "lightbulb")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct TeamResultView: View {
    let title: String
    let color: Color
    let players: [Int]
    let roles: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(color)

            LabeledContent("玩家") {
                Text(players.map(String.init).joined(separator: "，"))
                    .font(.body.monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }

            LabeledContent("角色") {
                Text(roles.joined(separator: "，"))
                    .fontWeight(.medium)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 10)
        }
    }
}

private struct PresentedError: Identifiable {
    let id = UUID()
    let message: String
}

#Preview("iPhone") {
    ContentView()
}

#Preview("iPad", traits: .fixedLayout(width: 1024, height: 1366)) {
    ContentView()
}
