import SwiftUI

struct UpdateAvailableSheet: View {
    let isDarkTheme: Bool
    let release: GitHubRelease
    let onUpdate: () -> Void
    let onLater: () -> Void

    private var palette: StudioPalette { isDarkTheme ? .dark : .light }

    var body: some View {
        ZStack {
            AtmosphereBackground()

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
                    AccentButton(title: "Обновить", action: onUpdate)
                    GhostButton(title: "Обновить позже", action: onLater)
                }
            }
            .padding(28)
            .softCard()
            .padding(24)
        }
        .frame(width: 340, height: 320)
        .environment(\.studioPalette, palette)
        .preferredColorScheme(isDarkTheme ? .dark : .light)
    }
}
