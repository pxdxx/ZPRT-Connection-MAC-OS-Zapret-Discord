import SwiftUI

struct PowerButtonView: View {
    @Environment(\.studioPalette) private var palette
    let running: Bool
    let busy: Bool
    var pulseToken: Int = 0
    let action: () -> Void

    @State private var breathe = false
    @State private var burst = false
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0

    var body: some View {
        Button(action: action) {
            ZStack {
                // activation ripples
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(palette.peachDeep.opacity(ringOpacity * (1.0 - Double(i) * 0.25)), lineWidth: 2)
                        .frame(width: 168, height: 168)
                        .scaleEffect(ringScale + CGFloat(i) * 0.18)
                        .opacity(burst ? 1 : 0)
                }

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: running
                                ? [palette.peach, palette.peachDeep]
                                : (palette.isDark
                                   ? [palette.field, palette.paper]
                                   : [Color.white, palette.field]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 168, height: 168)
                    .shadow(
                        color: running ? palette.peachDeep.opacity(0.5) : palette.shadow,
                        radius: running ? 32 : 16,
                        y: 14
                    )
                    .scaleEffect((breathe && running ? 1.04 : 1) * (burst ? 1.06 : 1))

                if busy {
                    ProgressView()
                        .controlSize(.large)
                        .tint(running ? palette.accentOn : palette.peachDeep)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: running ? "stop.fill" : "bolt.fill")
                            .font(.system(size: 36, weight: .bold))
                            .symbolEffect(.bounce, value: pulseToken)
                        Text(running ? "PAUSE" : "GO")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .tracking(2)
                    }
                    .foregroundStyle(running ? palette.accentOn : palette.ink)
                }
            }
            .frame(width: 210, height: 210)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: running)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .onChange(of: pulseToken) { _, _ in
            playBurst()
        }
        .onChange(of: running) { _, isOn in
            if isOn { playBurst() }
        }
        .accessibilityLabel(running ? "Выключить" : "Включить")
    }

    private func playBurst() {
        burst = false
        ringScale = 0.7
        ringOpacity = 0.9
        withAnimation(.easeOut(duration: 0.15)) {
            burst = true
        }
        withAnimation(.easeOut(duration: 0.85)) {
            ringScale = 1.55
            ringOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            burst = false
        }
    }
}

struct BottomNavBar: View {
    @Environment(\.studioPalette) private var palette
    let selection: AppScreen
    let onSelect: (AppScreen) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppScreen.allCases) { screen in
                Button {
                    onSelect(screen)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: screen.symbol)
                            .font(.system(size: 16, weight: .semibold))
                        Text(screen.title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(selection == screen ? palette.accentOn : palette.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .background {
                        if selection == screen {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [palette.peach, palette.peachDeep],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(palette.paper.opacity(palette.isDark ? 0.95 : 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(palette.isDark ? palette.lilac.opacity(0.2) : .clear, lineWidth: 1)
                )
                .shadow(color: palette.shadow, radius: 24, y: 12)
        )
    }
}

struct InfoCard: View {
    @Environment(\.studioPalette) private var palette
    let title: String
    let value: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(tint)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.inkFaint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.inkFaint)
                    Text(value)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .softCard(padding: 16, radius: 24)
        }
        .buttonStyle(.plain)
    }
}

struct NoticeBanner: View {
    @Environment(\.studioPalette) private var palette
    let notice: Notice
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notice.isError ? "exclamationmark.triangle.fill" : "sparkles")
                .foregroundStyle(notice.isError ? palette.danger : palette.peachDeep)
            Text(notice.text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(palette.inkFaint)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.paper)
                .shadow(color: palette.shadow, radius: 14, y: 8)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct ThemeToggleButton: View {
    @Environment(\.studioPalette) private var palette
    let isDark: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(palette.paper.opacity(0.95))
                    .shadow(color: palette.shadow.opacity(0.6), radius: 8, y: 4)
                Image(systemName: isDark ? "sun.max.fill" : "moon.stars.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isDark ? palette.peach : palette.ink)
                    .symbolEffect(.bounce, value: isDark)
                    .rotationEffect(.degrees(isDark ? 180 : 0))
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .help(isDark ? "Светлая тема" : "Тёмная тема")
    }
}
