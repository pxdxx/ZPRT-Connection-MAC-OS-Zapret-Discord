import SwiftUI

struct StudioPalette {
    var isDark: Bool

    var canvas: Color
    var canvasSoft: Color
    var peach: Color
    var peachDeep: Color
    var sky: Color
    var sage: Color
    var lilac: Color
    var ink: Color
    var inkSoft: Color
    var inkFaint: Color
    var paper: Color
    var field: Color
    var danger: Color
    var shadow: Color
    var blobPeach: Color
    var blobSky: Color
    var blobLilac: Color
    var blobSage: Color
    var accentOn: Color

    static let light = StudioPalette(
        isDark: false,
        canvas: Color(hex: 0xF6F1EA),
        canvasSoft: Color(hex: 0xE8F0F4),
        peach: Color(hex: 0xFF9B7A),
        peachDeep: Color(hex: 0xF06745),
        sky: Color(hex: 0x7EB6E8),
        sage: Color(hex: 0x4E9F7D),
        lilac: Color(hex: 0xC9B6F2),
        ink: Color(hex: 0x1A1A1A),
        inkSoft: Color(hex: 0x6B6570),
        inkFaint: Color(hex: 0xA39AA5),
        paper: Color.white,
        field: Color(hex: 0xF3EEE8),
        danger: Color(hex: 0xE5484D),
        shadow: Color(hex: 0xC4B5A5).opacity(0.45),
        blobPeach: Color(hex: 0xFF9B7A),
        blobSky: Color(hex: 0x7EB6E8),
        blobLilac: Color(hex: 0xC9B6F2),
        blobSage: Color(hex: 0x4E9F7D),
        accentOn: .white
    )

    /// Neon violet night — matched to the Discord-block app icon.
    static let dark = StudioPalette(
        isDark: true,
        canvas: Color(hex: 0x12081F),
        canvasSoft: Color(hex: 0x1A0B2E),
        peach: Color(hex: 0xFF4FD8),
        peachDeep: Color(hex: 0xFF2D9B),
        sky: Color(hex: 0x8B6CFF),
        sage: Color(hex: 0x5EE2A8),
        lilac: Color(hex: 0xB388FF),
        ink: Color(hex: 0xF4ECFF),
        inkSoft: Color(hex: 0xB9A7D4),
        inkFaint: Color(hex: 0x7E6E9A),
        paper: Color(hex: 0x231438),
        field: Color(hex: 0x2C1848),
        danger: Color(hex: 0xFF5C7A),
        shadow: Color(hex: 0x000000).opacity(0.55),
        blobPeach: Color(hex: 0xFF2D9B),
        blobSky: Color(hex: 0x6B4EFF),
        blobLilac: Color(hex: 0xA855F7),
        blobSage: Color(hex: 0x3D2A6D),
        accentOn: .white
    )
}

private struct StudioPaletteKey: EnvironmentKey {
    static let defaultValue = StudioPalette.light
}

extension EnvironmentValues {
    var studioPalette: StudioPalette {
        get { self[StudioPaletteKey.self] }
        set { self[StudioPaletteKey.self] = newValue }
    }
}

enum OutpostDimens {
    static let windowWidth: CGFloat = 440
    static let windowHeight: CGFloat = 780
    static let windowMinWidth: CGFloat = 400
    static let windowMinHeight: CGFloat = 640
    static let radiusCard: CGFloat = 32
    static let radiusField: CGFloat = 18
    static let radiusButton: CGFloat = 22
    static let radiusNav: CGFloat = 30
    static let navHeight: CGFloat = 56
    static let buttonHeight: CGFloat = 52
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

struct AtmosphereBackground: View {
    @Environment(\.studioPalette) private var palette
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.canvasSoft, palette.canvas],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Ellipse()
                .fill(palette.blobPeach.opacity(palette.isDark ? 0.35 : 0.45))
                .frame(width: 340, height: 260)
                .blur(radius: 70)
                .offset(x: drift ? -60 : -20, y: -220)

            Ellipse()
                .fill(palette.blobSky.opacity(palette.isDark ? 0.35 : 0.4))
                .frame(width: 300, height: 280)
                .blur(radius: 65)
                .offset(x: drift ? 90 : 50, y: 40)

            Ellipse()
                .fill(palette.blobLilac.opacity(palette.isDark ? 0.4 : 0.35))
                .frame(width: 280, height: 240)
                .blur(radius: 70)
                .offset(x: -80, y: drift ? 380 : 420)

            Ellipse()
                .fill(palette.blobSage.opacity(palette.isDark ? 0.35 : 0.25))
                .frame(width: 220, height: 200)
                .blur(radius: 55)
                .offset(x: 110, y: 520)
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.7, dampingFraction: 0.85), value: palette.isDark)
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

struct SoftCardModifier: ViewModifier {
    @Environment(\.studioPalette) private var palette
    var padding: CGFloat = 18
    var radius: CGFloat = OutpostDimens.radiusCard

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(palette.paper.opacity(palette.isDark ? 0.92 : 0.86))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(palette.isDark ? palette.lilac.opacity(0.18) : Color.white.opacity(0.7), lineWidth: 1)
                    )
                    .shadow(color: palette.shadow, radius: palette.isDark ? 18 : 22, y: 12)
            )
    }
}

extension View {
    func softCard(padding: CGFloat = 18, radius: CGFloat = OutpostDimens.radiusCard) -> some View {
        modifier(SoftCardModifier(padding: padding, radius: radius))
    }
}
