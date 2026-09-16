import SwiftUI

struct PlatformPickerSheet: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    let alreadyAdded: (PopularPlatform) -> Bool
    let onAdd: (PopularPlatform) -> Void

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

            Text("Добавляет актуальные домены платформы в «Домены пользователя», не стирая то, что уже есть.")
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
            onAdd(platform)
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: platform.tintHex).opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: platform.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: platform.tintHex))
                }
                Text(platform.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                Text(added ? "добавлено" : "\(platform.domains.count) доменов")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(added ? palette.sage : palette.inkFaint)
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
