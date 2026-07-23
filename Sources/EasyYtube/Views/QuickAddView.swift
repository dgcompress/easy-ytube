import SwiftUI

struct QuickAddView: View {
    @ObservedObject private var queue = DownloadQueueManager.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var urlText: String = ""

    var onOpenMainWindow: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.tint)
                Text("EasyYtube")
                    .font(.headline)
            }

            URLEntryBar(
                urlText: $urlText,
                destinationFolder: queue.destinationFolder,
                onSubmit: submit,
                onOpenFolder: queue.openDestinationFolder
            )

            if let last = queue.items.last {
                QueueItemCard(
                    item: last,
                    onReveal: { queue.revealInFinder(last) },
                    onRetry: { queue.retry(last) },
                    onCancel: { queue.cancel(last) }
                )
            }

            Divider()

            HStack {
                Button(L("Apri finestra completa"), action: onOpenMainWindow)
                    .buttonStyle(.link)
                    .font(.caption)
                Spacer()
                Button(L("Esci"), action: onQuit)
                    .buttonStyle(.link)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func submit() {
        let text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        queue.addURL(text)
        DispatchQueue.main.async { urlText = "" }
    }
}
