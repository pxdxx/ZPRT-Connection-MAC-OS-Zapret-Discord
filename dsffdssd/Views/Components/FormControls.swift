import SwiftUI

struct SettingsSection<Content: View>: View {
    @Environment(\.studioPalette) private var palette
    let title: String
    var description: String? = nil
    var credit: String? = nil
    var accent: Color? = nil
    @ViewBuilder var content: Content

    private var accentColor: Color { accent ?? palette.peachDeep }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Capsule()
                    .fill(accentColor)
                    .frame(width: 5, height: 20)
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.ink)
                Spacer()
                if let credit {
                    Text(credit)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(accentColor.opacity(0.14)))
                }
            }

            if let description {
                Text(description)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .softCard()
    }
}

struct SwitchRow: View {
    @Environment(\.studioPalette) private var palette
    let label: String
    var description: String? = nil
    @Binding var isOn: Bool
    var enabled: Bool = true

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.ink)
                if let description {
                    Text(description)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(palette.peachDeep)
        .disabled(!enabled)
    }
}

struct ChoiceRow: View {
    @Environment(\.studioPalette) private var palette
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.ink)
                Spacer()
                ZStack {
                    Circle()
                        .stroke(selected ? palette.peachDeep : palette.inkFaint.opacity(0.45), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle()
                            .fill(palette.peachDeep)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? palette.peach.opacity(0.18) : palette.field)
            )
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    @Environment(\.studioPalette) private var palette
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(enabled ? palette.ink : palette.inkFaint)
                .frame(maxWidth: .infinity)
                .frame(height: OutpostDimens.buttonHeight)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: OutpostDimens.radiusButton, style: .continuous)
                        .fill(palette.paper.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: OutpostDimens.radiusButton, style: .continuous)
                                .stroke(palette.inkFaint.opacity(0.22), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct AccentButton: View {
    @Environment(\.studioPalette) private var palette
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(palette.accentOn)
                .frame(maxWidth: .infinity)
                .frame(height: OutpostDimens.buttonHeight)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: OutpostDimens.radiusButton, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: enabled
                                    ? [palette.peach, palette.peachDeep]
                                    : [palette.inkFaint, palette.inkFaint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: enabled ? palette.peachDeep.opacity(0.35) : .clear, radius: 14, y: 8)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct TextActionButton: View {
    @Environment(\.studioPalette) private var palette
    let title: String
    var danger: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(
                    enabled
                        ? (danger ? palette.danger : palette.peachDeep)
                        : palette.inkFaint
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct LabeledField: View {
    @Environment(\.studioPalette) private var palette
    let label: String
    @Binding var text: String
    var mono: Bool = false
    var minHeight: CGFloat = 36
    var enabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(palette.inkFaint)

            Group {
                if minHeight > 60 {
                    TextEditor(text: $text)
                        .font(mono ? .system(size: 12, design: .monospaced) : .system(size: 13, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: minHeight, maxHeight: minHeight + 80)
                } else {
                    TextField("", text: $text)
                        .font(mono ? .system(size: 12, design: .monospaced) : .system(size: 13, design: .rounded))
                        .textFieldStyle(.plain)
                }
            }
            .foregroundStyle(palette.ink)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: OutpostDimens.radiusField, style: .continuous)
                    .fill(palette.field)
            )
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.55)
        }
    }
}
