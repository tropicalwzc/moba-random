import SwiftUI
import UIKit

struct Bo3AvatarView: View {
    let name: String
    let size: CGFloat
    var isUsed: Bool = false
    var showsElementRing: Bool = true

    @State private var image: UIImage?
    @State private var descriptor: Bo3AvatarDescriptor?

    var body: some View {
        let resolved = descriptor ?? Bo3AvatarCatalog.shared.descriptor(for: name)
        let corner = size * 0.28

        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback(for: resolved)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay {
            if showsElementRing, resolved.hasImage {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Bo3Palette.elementColor(for: resolved.element), lineWidth: 1.5)
            }
        }
        .saturation(isUsed ? 0 : 1)
        .opacity(isUsed ? 0.55 : 1)
        .onAppear { load() }
        .onChange(of: name) { _, _ in load() }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func fallback(for descriptor: Bo3AvatarDescriptor) -> some View {
        let colors = Bo3Palette.fallbackColors(seed: descriptor.fallbackSeed)
        ZStack {
            LinearGradient(
                colors: [colors.0, colors.1],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(descriptor.displayName.prefix(1)))
                .font(.system(size: size * 0.42, weight: .heavy))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
    }

    private func load() {
        let resolved = Bo3AvatarCatalog.shared.descriptor(for: name)
        descriptor = resolved
        image = Bo3AvatarCatalog.shared.image(for: resolved)
    }
}

#Preview("BO3 avatars") {
    HStack(spacing: 12) {
        Bo3AvatarView(name: "温迪", size: 56)
        Bo3AvatarView(name: "公子", size: 56)
        Bo3AvatarView(name: "点刀", size: 56)
        Bo3AvatarView(name: "未知角色", size: 56)
        Bo3AvatarView(name: "甘雨", size: 56, isUsed: true)
    }
    .padding()
}
