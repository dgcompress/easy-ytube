import SwiftUI
import AppKit

struct FooterView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Creato da doubleg")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 22) {
                FooterLink(icon: "envelope", label: "gabrielsturzu@gmail.com") {
                    open("mailto:gabrielsturzu@gmail.com")
                }
                FooterLink(icon: "heart.fill", label: "Offrimi un caffè", tint: .pink) {
                    open("https://revolut.me/doublegevents")
                }
                FooterLink(icon: "globe", label: "doublegevents.it") {
                    open("https://www.doublegevents.it")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct FooterLink: View {
    let icon: String
    let label: LocalizedStringKey
    var tint: Color = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(label)
            }
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}
