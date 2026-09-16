import SwiftUI

struct PlatformPickerSheet: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    let alreadyAdded: (PopularPlatform) -> Bool
    let onToggle: (PopularPlatform) -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("популярные платформы")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.ink)
                Spacer()
                Button("Готово") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.peachDeep)
            }

            Text("Добавляет актуальные домены платформы к списку, не стирая то, что уже есть. Нажми ещё раз, чтобы убрать.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.inkSoft)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array.popularPlatforms) { platform in
                        platformTile(platform)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 380, height: 480)
        .background(palette.canvas)
    }

    private func platformTile(_ platform: PopularPlatform) -> some View {
        let added = alreadyAdded(platform)
        return Button {
            onToggle(platform)
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: platform.tintHex).opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(platform.assetName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                    if added {
                        Circle()
                            .fill(palette.sage)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 16, y: 16)
                    }
                }
                Text(platform.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                Text(added ? "убрать" : "\(platform.domains.count) доменов")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(added ? palette.danger : palette.inkFaint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: OutpostDimens.radiusField, style: .continuous)
                    .fill(palette.paper.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: OutpostDimens.radiusField, style: .continuous)
                            .stroke(added ? palette.sage.opacity(0.5) : palette.inkFaint.opacity(0.18), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
