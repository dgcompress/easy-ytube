import SwiftUI
import AppKit

struct UpdateBannerView: View {
    @ObservedObject var checker: UpdateChecker

    var body: some View {
        if checker.isAvailable {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nuova versione disponibile: v\(checker.latestVersion)")
                        .font(.caption.weight(.semibold))
                    if !checker.notes.isEmpty {
                        Text(checker.notes)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Scarica") {
                    if let url = checker.downloadURL {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    checker.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.18), Color.pink.opacity(0.18)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.35)))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
