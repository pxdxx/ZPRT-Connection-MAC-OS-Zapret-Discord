import SwiftUI

struct DiagnosticsSheet: View {
    @Environment(\.studioPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    let text: String
    let onCopy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("диагностика")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.ink)
                Spacer()
                Button("Готово") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.peachDeep)
            }

            ScrollView(showsIndicators: true) {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: OutpostDimens.radiusField, style: .continuous)
                    .fill(palette.field)
            )

            AccentButton(title: "Скопировать") {
                onCopy(text)
            }
        }
        .padding(20)
        .frame(width: 420, height: 480)
        .background(palette.canvas)
    }
}
