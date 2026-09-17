import SwiftUI

struct UpdateAvailableSheet: View {
    @Environment(\.studioPalette) private var palette
    let release: GitHubRelease
    let updating: Bool
    let onUpdate: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(palette.sage)

            VStack(spacing: 6) {
                Text("Доступна новая версия")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.inkSoft)
                Text("v\(Updater.displayVersion(release.tagName))")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(palette.ink)
            }

            VStack(spacing: 10) {
                AccentButton(
                    title: updating ? "Обновляется…" : "Обновить",
                    enabled: !updating,
                    action: onUpdate
                )
                GhostButton(
                    title: "Обновить позже",
                    enabled: !updating,
                    action: onLater
                )
            }
        }
        .padding(28)
        .frame(width: 320)
        .background(palette.canvas)
    }
}
