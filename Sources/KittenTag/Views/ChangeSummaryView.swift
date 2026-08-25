import SwiftUI

struct ChangeSummaryView: View {
    let summaries: [TrackChangeSummary]
    let save: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.string("Değişiklikleri Kaydet"))
                    .font(.title2.weight(.semibold))
                Text(L10n.format("%lld dosyaya yazılacak değişiklikleri son kez kontrol edin.", Int64(summaries.count)))
                    .foregroundStyle(.secondary)
            }

            List(summaries) { summary in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(summary.changes) { change in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(L10n.string(change.label))
                                    .frame(width: 110, alignment: .leading)
                                    .foregroundStyle(.secondary)
                                Text(display(change.before))
                                    .lineLimit(2)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(display(change.after))
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                            }
                            .font(.callout)
                        }
                    }
                    .padding(.vertical, 6)
                } label: {
                    HStack {
                        Text(summary.filename)
                            .lineLimit(1)
                        Spacer()
                        Text(L10n.format("%lld değişiklik", Int64(summary.changes.count)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 360)

            HStack {
                Spacer()
                Button(L10n.string("Vazgeç")) { dismiss() }
                    .buttonStyle(KTButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(L10n.string("Kaydet")) {
                    dismiss()
                    save()
                }
                .buttonStyle(KTButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 720)
        .background(Color.ktCanvas)
    }

    private func display(_ value: String) -> String { value.isEmpty ? L10n.string("Boş") : value }
}
